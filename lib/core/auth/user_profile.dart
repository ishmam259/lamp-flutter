import '../models/domain_models.dart';
import '../state/lamp_state.dart';
import '../world/seed.dart';
import 'accounts.dart';

/// What someone chose at registration: which seat they hold, and which
/// pharmacy, delivery round or bank it is. Stored at `users/{uid}`.
class UserProfile {
  final String uid;
  final String name;
  final PersonaId seat;

  /// For a pharmacy owner: the pharmacy (`did:lamp:…`) whose seat this opens.
  final String? pharmacyDid;

  /// For a delivery officer: whose round this opens.
  final String? mpoId;

  /// For a bank: which bank's desk this opens on.
  final Msp? bank;

  final String? phone;
  final String? email;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.seat,
    this.pharmacyDid,
    this.mpoId,
    this.bank,
    this.phone,
    this.email,
  });

  /// The thing this person exclusively holds, or null for a desk seat that
  /// several people can share. A pharmacy and a delivery round belong to one
  /// person each; a bank desk, the manufacturer and the regulator do not.
  String? get claimId => switch (seat) {
        PersonaId.pharmacy when pharmacyDid != null => 'pharmacy-${pharmacyDid!.split(':').last}',
        PersonaId.mpo when mpoId != null => 'mpo-$mpoId',
        _ => null,
      };

  Map<String, dynamic> toJson() => {
        'name': name,
        'seat': seat.id,
        if (pharmacyDid != null) 'pharmacyDid': pharmacyDid,
        if (mpoId != null) 'mpoId': mpoId,
        if (bank != null) 'bank': bank!.id,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      };

  factory UserProfile.fromJson(String uid, Map<String, dynamic> json) {
    final seatId = json['seat'] as String?;
    return UserProfile(
      uid: uid,
      name: (json['name'] as String?) ?? 'LaMP user',
      seat: PersonaId.values.firstWhere(
        (p) => p.id == seatId,
        orElse: () => PersonaId.regulator,
      ),
      pharmacyDid: json['pharmacyDid'] as String?,
      mpoId: json['mpoId'] as String?,
      bank: json['bank'] == null ? null : Msp.fromId(json['bank'] as String),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  /// The seat this profile opens, in the shape the rest of the app reads.
  Account toAccount() {
    final id = 'user-$uid';
    switch (seat) {
      case PersonaId.mpo:
        final m = SeedData.mpos.firstWhere(
          (m) => m.id == mpoId,
          orElse: () => SeedData.mpos.first,
        );
        return Account(
          id: id,
          name: name,
          org: SeedData.manufacturer.name,
          role: 'Delivery officer · ${m.territory}',
          seat: seat,
          mpoId: m.id,
        );
      case PersonaId.pharmacy:
        final p = SeedData.pharmacies.firstWhere(
          (p) => p.did == pharmacyDid,
          orElse: () => SeedData.pharmacies.first,
        );
        return Account(
          id: id,
          name: name,
          org: p.name,
          role: 'Pharmacy owner · ${p.territory}',
          seat: seat,
          pharmacyDid: p.did,
        );
      case PersonaId.manufacturer:
        return Account(
          id: id,
          name: name,
          org: SeedData.manufacturer.name,
          role: 'Manufacturer',
          seat: seat,
        );
      case PersonaId.bank:
        final b = bank ?? Msp.meghnaMSP;
        return Account(
          id: id,
          name: name,
          org: b.fullName,
          role: 'Bank',
          seat: seat,
          bank: b,
        );
      case PersonaId.regulator:
        return Account(
          id: id,
          name: name,
          org: Msp.regulatorMSP.fullName,
          role: 'Regulator · view only',
          seat: seat,
        );
    }
  }
}
