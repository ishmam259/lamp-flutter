import '../models/domain_models.dart';
import '../state/lamp_state.dart';
import '../world/seed.dart';

/// Someone who can sign in, and the seat they land in.
///
/// On-device for now: the roster is the organisations the world is seeded
/// with. When there is a server, it hands back one of these after it has
/// checked the credentials, and nothing downstream changes.
class Account {
  final String id;

  /// The person or desk, as it should appear on the sign-in list.
  final String name;

  /// Their organisation.
  final String org;

  /// What they do — the line under the name.
  final String role;

  final PersonaId seat;

  /// For a bank account, which bank's desk the Financing seat opens on.
  final Msp? bank;

  /// For a pharmacy account, which pharmacy the seat shows.
  final String? pharmacyDid;

  /// For a delivery officer, whose round the seat shows.
  final String? mpoId;

  const Account({
    required this.id,
    required this.name,
    required this.org,
    required this.role,
    required this.seat,
    this.bank,
    this.pharmacyDid,
    this.mpoId,
  });

  /// Field seats run on a phone at a pharmacy door; desk seats at a desk.
  bool get isField => seat == PersonaId.mpo || seat == PersonaId.pharmacy;
}

class Accounts {
  /// Every officer and every pharmacy the world is seeded with, then the
  /// desks. Each field account carries the id its seat reads, so a second
  /// pharmacy sees its own invoices and credit, not the first one's.
  static final List<Account> all = [
    for (final m in SeedData.mpos)
      Account(
        id: m.id,
        name: m.name,
        org: SeedData.manufacturer.name,
        role: 'Delivery officer · ${m.territory}',
        seat: PersonaId.mpo,
        mpoId: m.id,
      ),
    for (final p in SeedData.pharmacies)
      Account(
        id: 'pharmacy-${p.did.split(':').last}',
        name: p.ownerName,
        org: p.name,
        role: 'Pharmacy owner · ${p.territory}',
        seat: PersonaId.pharmacy,
        pharmacyDid: p.did,
      ),
    Account(
      id: 'mfr-shomota',
      name: 'Receivables desk',
      org: SeedData.manufacturer.name,
      role: 'Manufacturer',
      seat: PersonaId.manufacturer,
    ),
    Account(
      id: 'bank-meghna',
      name: 'Trade finance desk',
      org: Msp.meghnaMSP.fullName,
      role: 'Bank',
      seat: PersonaId.bank,
      bank: Msp.meghnaMSP,
    ),
    Account(
      id: 'bank-padma',
      name: 'Trade finance desk',
      org: Msp.padmaMSP.fullName,
      role: 'Bank',
      seat: PersonaId.bank,
      bank: Msp.padmaMSP,
    ),
    Account(
      id: 'regulator',
      name: 'Supervision',
      org: Msp.regulatorMSP.fullName,
      role: 'Regulator · view only',
      seat: PersonaId.regulator,
    ),
  ];

  static Account? byId(String? id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// The first account that opens [seat] — what the testing tools switch to.
  static Account forSeat(PersonaId seat) =>
      all.firstWhere((a) => a.seat == seat);
}
