import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/webs_colors.dart';
import 'bw_api.dart';
import 'bw_delivery_screen.dart';
import 'bw_saved_deliveries.dart';

/// "Track" tab (replaces the old Security tab).
///
/// Buyers and sellers meet here on the map while a BestWinger product is being
/// delivered. It works together with the BestWinger website: one person can use
/// the website and the other the Webs app.
class BwTrackScreen extends StatefulWidget {
  const BwTrackScreen({super.key});

  @override
  State<BwTrackScreen> createState() => _BwTrackScreenState();
}

class _BwTrackScreenState extends State<BwTrackScreen> {
  static const Color _orange = Color(0xFFFF6B00);
  static const Color _navy = Color(0xFF0F2B5B);

  final TextEditingController _input = TextEditingController();
  List<BwSavedDelivery> _saved = [];
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _refreshSaved();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _refreshSaved() async {
    final list = await BwSavedDeliveries.load();
    if (mounted) setState(() => _saved = list);
  }

  Future<void> _openDelivery(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _refreshSaved();
  }

  /// Accepts a tracking code (buyer) or the secure link from a BestWinger email (seller).
  void _track() {
    final text = _input.text.trim();
    if (BwApi.isSellerLink(text)) {
      setState(() => _inputError = null);
      _openDelivery(BwDeliveryScreen.seller(link: text));
      return;
    }
    final code = BwApi.normalizeCode(text);
    if (!RegExp(r'^BW-[A-Z0-9]{6}$').hasMatch(code)) {
      setState(() => _inputError = 'Enter your tracking code, like BW-7Q3K9P');
      return;
    }
    setState(() => _inputError = null);
    FocusScope.of(context).unfocus();
    _openDelivery(BwDeliveryScreen.buyer(code: code));
  }

  Future<void> _visitBestWinger() async {
    await launchUrl(Uri.parse(kBestWingerUrl), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final textDark = WebsColors.textDark(context);
    final textLight = WebsColors.textLight(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Track')),
      body: RefreshIndicator(
        onRefresh: _refreshSaved,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // ---- What this is
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WebsColors.softGreen(context),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 36, color: WebsColors.primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Meet on the map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textDark)),
                        const SizedBox(height: 4),
                        Text(
                          'Follow a BestWinger delivery live: the buyer and the seller see each other '
                          'until the product is handed over. One of you can use the website and the other Webs.',
                          style: TextStyle(color: textLight, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ---- Track by code (or seller link)
            Text('Track a delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
            const SizedBox(height: 8),
            TextField(
              controller: _input,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _track(),
              decoration: InputDecoration(
                hintText: 'BW-7Q3K9P',
                helperText: 'Your tracking code from BestWinger. Sellers can paste the link from their order email.',
                helperMaxLines: 2,
                errorText: _inputError,
                prefixIcon: const Icon(Icons.qr_code_2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _track,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Track on the map', style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            // ---- Recent deliveries
            if (_saved.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('Your deliveries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
              const SizedBox(height: 6),
              ..._saved.map((d) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: d.isSeller ? const Color(0xFFFFF8E1) : const Color(0xFFFFF3E0),
                        child: Icon(d.isSeller ? Icons.storefront : Icons.shopping_bag_outlined,
                            color: d.isSeller ? const Color(0xFFB8860B) : const Color(0xFFF57C00)),
                      ),
                      title: Text(d.title.isEmpty ? d.code : d.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${d.code} · ${d.isSeller ? 'You are the seller' : 'You are the buyer'}'),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await BwSavedDeliveries.forget(d.key);
                          _refreshSaved();
                        },
                      ),
                      onTap: () => _openDelivery(
                        d.isSeller ? BwDeliveryScreen.seller(link: d.key) : BwDeliveryScreen.buyer(code: d.key),
                      ),
                    ),
                  )),
            ],

            // ---- Visit BestWinger
            const SizedBox(height: 22),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _visitBestWinger,
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Visit BestWinger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 6),
            Text(
              'Buy and sell near you on bestwinger.webzapp.org',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: textLight),
            ),
          ],
        ),
      ),
    );
  }
}
