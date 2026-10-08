import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// Import platform printer via receipt_print_stub / web / mobile
import '../../services/receipt_print_stub.dart'
    if (dart.library.html) '../../services/receipt_print_web.dart'
    if (dart.library.io) '../../services/receipt_print_mobile.dart';

/// Modal dialog for managing and connecting Bluetooth 58mm thermal printers (MPT-II).
class BluetoothPrinterDialog extends StatefulWidget {
  const BluetoothPrinterDialog({super.key});

  /// Displays the Bluetooth printer selection dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const BluetoothPrinterDialog(),
    );
  }

  @override
  State<BluetoothPrinterDialog> createState() => _BluetoothPrinterDialogState();
}

class _BluetoothPrinterDialogState extends State<BluetoothPrinterDialog> {
  bool _isLoading = true;
  bool _isConnecting = false;
  bool _isTestingPrint = false;
  bool _isConnected = false;
  String? _errorMessage;
  String? _successMessage;
  List<dynamic> _pairedDevices = [];
  String? _connectingMac;

  @override
  void initState() {
    super.initState();
    _loadStatusAndDevices();
  }

  Future<void> _loadStatusAndDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (kIsWeb) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bluetooth thermal printing is only supported on Android. Web uses browser print.';
      });
      return;
    }

    try {
      final hasPermission = await ReceiptPlatformPrinter.isPermissionGranted();
      if (!hasPermission && mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Bluetooth permission (Nearby devices) is required. Please grant permission.';
        });
        return;
      }

      final connected = await ReceiptPlatformPrinter.isConnected();
      final devices = await ReceiptPlatformPrinter.getPairedPrinters();

      if (!mounted) return;
      setState(() {
        _isConnected = connected;
        _pairedDevices = devices;
        _isLoading = false;
        if (ReceiptPlatformPrinter.lastErrorMessage != null) {
          _errorMessage = ReceiptPlatformPrinter.lastErrorMessage;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load Bluetooth devices: $e';
      });
    }
  }

  Future<void> _connectToPrinter(String macAddress, String name) async {
    setState(() {
      _isConnecting = true;
      _connectingMac = macAddress;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final success = await ReceiptPlatformPrinter.connect(macAddress, printerName: name);
      if (!mounted) return;

      setState(() {
        _isConnecting = false;
        _connectingMac = null;
        _isConnected = success;
        if (success) {
          _successMessage = 'Connected to $name';
        } else {
          _errorMessage = ReceiptPlatformPrinter.lastErrorMessage ?? 'Connection failed. Ensure $name is turned on.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _connectingMac = null;
        _isConnected = false;
        _errorMessage = 'Connection error: $e';
      });
    }
  }

  Future<void> _disconnectPrinter() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ReceiptPlatformPrinter.disconnect();
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _successMessage = 'Printer disconnected';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _errorMessage = 'Error disconnecting: $e';
      });
    }
  }

  Future<void> _testPrint() async {
    setState(() {
      _isTestingPrint = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final ok = await ReceiptPlatformPrinter.printTestReceipt();
      if (!mounted) return;

      setState(() {
        _isTestingPrint = false;
        if (ok) {
          _successMessage = 'Test receipt sent to printer!';
        } else {
          _errorMessage = ReceiptPlatformPrinter.lastErrorMessage ?? 'Test print failed.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTestingPrint = false;
        _errorMessage = 'Test print error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.print, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bluetooth Thermal Printer',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'MPT-II / POS58 (58mm)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh paired printers',
                    onPressed: (_isLoading || _isConnecting) ? null : _loadStatusAndDevices,
                  ),
                ],
              ),
              const Divider(height: 24),

              // Status message banners
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.dangerDark, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.dangerDark, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.successDark, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: AppColors.successDark, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Connection status card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _isConnected ? AppColors.successLight : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isConnected ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                      color: _isConnected ? AppColors.success : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isConnected
                                ? 'Connected: ${ReceiptPlatformPrinter.savedPrinterName ?? 'MPT-II'}'
                                : 'No Printer Connected',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isConnected ? AppColors.successDark : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _isConnected
                                ? (ReceiptPlatformPrinter.savedMacAddress ?? 'SPP Ready')
                                : 'Select and connect to MPT-II below',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (_isConnected) ...[
                      TextButton(
                        onPressed: _isConnecting ? null : _disconnectPrinter,
                        child: const Text('Disconnect', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Test print button if connected
              if (_isConnected) ...[
                OutlinedButton.icon(
                  icon: _isTestingPrint
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.print, size: 16),
                  label: const Text('Print Test Receipt (58mm)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  onPressed: (_isTestingPrint || _isConnecting) ? null : _testPrint,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Paired devices header
              const Text(
                'PAIRED BLUETOOTH DEVICES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Device list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                    : _pairedDevices.isEmpty
                        ? Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(20),
                            child: const Text(
                              'No paired devices found.\nPlease pair your MPT-II thermal printer in phone Bluetooth Settings first.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _pairedDevices.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final device = _pairedDevices[index];
                              final String name = (device.name as String?)?.trim().isNotEmpty == true
                                  ? device.name as String
                                  : 'Bluetooth Device';
                              final String mac = (device.macAdress as String?) ?? '';
                              final bool isMpt = name.toUpperCase().contains('MPT') ||
                                  name.toUpperCase().contains('POS58') ||
                                  name.toUpperCase().contains('PRINTER');
                              final bool isCurrent = _isConnected && ReceiptPlatformPrinter.savedMacAddress == mac;
                              final bool isConnectingThis = _isConnecting && _connectingMac == mac;

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isMpt ? AppColors.primaryLight : AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.print_outlined,
                                    size: 18,
                                    color: isMpt ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: isMpt ? FontWeight.w700 : FontWeight.w500,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (isMpt)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'MPT-II',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  mac,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                trailing: isCurrent
                                    ? const Chip(
                                        label: Text('Connected', style: TextStyle(fontSize: 11, color: Colors.white)),
                                        backgroundColor: AppColors.success,
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      )
                                    : isConnectingThis
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isMpt ? AppColors.primary : AppColors.surface,
                                              foregroundColor: isMpt ? Colors.white : AppColors.primary,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              elevation: 0,
                                            ),
                                            onPressed: _isConnecting
                                                ? null
                                                : () => _connectToPrinter(mac, name),
                                            child: const Text('Connect'),
                                          ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 12),

              // Close button
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
