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

  const Account({
    required this.id,
    required this.name,
    required this.org,
    required this.role,
    required this.seat,
    this.bank,
  });

  /// Field seats run on a phone at a pharmacy door; desk seats at a desk.
  bool get isField => seat == PersonaId.mpo || seat == PersonaId.pharmacy;
}

class Accounts {
  static final List<Account> all = [
    Account(
      id: SeedData.mpos[0].id,
      name: SeedData.mpos[0].name,
      org: SeedData.manufacturer.name,
      role: 'Delivery officer · ${SeedData.mpos[0].territory}',
      seat: PersonaId.mpo,
    ),
    Account(
      id: 'pharmacy-${SeedData.pharmacies[0].did.split(':').last}',
      name: SeedData.pharmacies[0].ownerName,
      org: SeedData.pharmacies[0].name,
      role: 'Pharmacy owner · ${SeedData.pharmacies[0].territory}',
      seat: PersonaId.pharmacy,
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
