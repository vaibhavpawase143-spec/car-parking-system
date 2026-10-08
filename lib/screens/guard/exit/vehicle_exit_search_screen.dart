import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/parking_record_model.dart';
import '../../../services/parking_service.dart';
import '../../../widgets/camera/qr_scanner_dialog.dart';
import 'matching_vehicles_dialog.dart';
import 'vehicle_exit_verification_screen.dart';

/// Guard Vehicle Exit search screen supporting:
/// A) Full vehicle registration search (e.g. MH23ER5656)
/// B) Partial last digits of vehicle number (e.g. 5656, 656, 56, 6)
/// C) Exact/partial numeric ticket number (e.g. 1004, 004, 04, 4)
/// D) Legacy TKT ticket number (e.g. TKT-20260923-4K0D)
/// E) Direct live camera QR scanning for physical receipts
class VehicleExitSearchScreen extends StatefulWidget {
  final GuardModel currentGuard;
  final VoidCallback onReturnDashboard;
  final ParkingService? parkingService;

  const VehicleExitSearchScreen({
    super.key,
    required this.currentGuard,
    required this.onReturnDashboard,
    this.parkingService,
  });

  @override
  State<VehicleExitSearchScreen> createState() => _VehicleExitSearchScreenState();
}

class _VehicleExitSearchScreenState extends State<VehicleExitSearchScreen> {
  final _searchController = TextEditingController();
  late final ParkingService _parkingService;

  bool _isSearching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _parkingService = widget.parkingService ?? ParkingService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetSearch() {
    _searchController.clear();
    setState(() {
      _errorMessage = null;
      _isSearching = false;
    });
  }

  void _navigateToVerification(ParkingRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleExitVerificationScreen(
          record: record,
          currentGuard: widget.currentGuard,
          onReturnDashboard: widget.onReturnDashboard,
          onExitAnotherVehicle: _resetSearch,
          parkingService: _parkingService,
        ),
      ),
    );
  }

  /// Handles QR Code scan button press: DIRECTLY opens the live camera QR scanner.
  Future<void> _handleScanQrCode() async {
    setState(() {
      _errorMessage = null;
    });

    final scannedTicket = await QrScannerDialog.show(context);
    if (!mounted || scannedTicket == null || scannedTicket.trim().isEmpty) {
      return;
    }

    _searchController.text = scannedTicket.trim().toUpperCase();
    await _performSearch(scannedTicket);
  }

  /// Searches for an ACTIVE vehicle by vehicle number, suffix digits, numeric ticket, or legacy ticket.
  /// - If 1 active match: opens Vehicle Exit Verification directly.
  /// - If >1 active matches: shows result list with [ Select Vehicle ] (never auto-selects).
  /// - If 0 matches: shows precise error message.
  Future<void> _performSearch([String? overrideQuery]) async {
    final query = (overrideQuery ?? _searchController.text).trim();

    if (query.isEmpty) {
      setState(() {
        _errorMessage = AppStrings.searchByVehicleOrTicket;
      });
      return;
    }

    debugPrint('[VehicleExitSearchScreen] User triggered search for query="$query"');

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final matches = await _parkingService.searchTicketsForExit(query);
      debugPrint('[VehicleExitSearchScreen] Search returned ${matches.length} matching active record(s)');
      if (!mounted) return;

      setState(() {
        _isSearching = false;
      });

      if (matches.length == 1) {
        // Exactly one ACTIVE match -> open Vehicle Exit Verification directly
        debugPrint('[VehicleExitSearchScreen] Exactly 1 match found: ${matches.first.vehicleNumber} (${matches.first.ticketNumber}). Navigating directly to Verification.');
        _navigateToVerification(matches.first);
      } else if (matches.length > 1) {
        // Multiple ACTIVE matches -> require Guard to explicitly select one
        debugPrint('[VehicleExitSearchScreen] Multiple matches (${matches.length}). Showing MatchingVehiclesDialog.');
        final selected = await MatchingVehiclesDialog.show(
          context,
          matchingRecords: matches,
          searchQuery: query,
        );
        if (mounted && selected != null) {
          _navigateToVerification(selected);
        }
      }
    } on TicketNotFoundException {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = AppStrings.ticketNotFound;
        });
      }
    } on VehicleAlreadyExitedException {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = AppStrings.vehicleAlreadyExited;
        });
      }
    } on VehicleNotActiveException {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = AppStrings.vehicleNotParked;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = '${AppStrings.error}: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Header
                  Center(
                    child: Text(
                      AppStrings.vehicleExit,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      AppStrings.searchExitSubtitle,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      key: const ValueKey('exit_error_banner'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.dangerDark, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.dangerDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Search Field
                  TextField(
                    key: const ValueKey('exit_ticket_input_field'),
                    controller: _searchController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: AppStrings.searchByVehicleOrTicket,
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _errorMessage = null;
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _performSearch(),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      AppStrings.exitExamples,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons: [ Search Active Vehicle ]    [ Scan QR ]
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          key: const ValueKey('exit_ticket_search_button'),
                          icon: _isSearching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search, size: 18, color: Colors.white),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              AppStrings.searchActiveVehicle,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: _isSearching ? null : () => _performSearch(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('scan_qr_code_button'),
                          icon: const Icon(Icons.qr_code_scanner, size: 18, color: AppColors.primary),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              AppStrings.scanQr,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isSearching ? null : _handleScanQrCode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
