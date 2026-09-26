import 'user_profile.dart';

/// Who the sign-in provider says someone is, before they have a seat.
class AuthUser {
  /// Stable id from the provider. Firestore documents are keyed by it.
  final String uid;
  final String? phone;
  final String? email;
  final String? displayName;

  const AuthUser({
    required this.uid,
    this.phone,
    this.email,
    this.displayName,
  });

  /// What to call them before they have told us: their Google name, else the
  /// part of their email before the @, else their number.
  String get suggestedName =>
      displayName ?? email?.split('@').first ?? phone ?? 'New user';
}

/// A code has been sent to a number and is waiting to be entered.
class PhoneChallenge {
  final String phone;

  /// Provider-specific handle needed to check the code.
  final String token;

  const PhoneChallenge({required this.phone, required this.token});
}

enum AuthFailureKind {
  /// The person closed the sign-in sheet. Not an error worth showing.
  cancelled,
  invalidPhone,
  invalidCode,
  codeExpired,
  tooManyAttempts,
  network,

  /// Another account already holds that pharmacy or delivery round.
  seatTaken,
  other,
}

/// A sign-in or registration problem, with copy fit to show a person. Provider
/// error codes never reach the screen.
class AuthFailure implements Exception {
  final AuthFailureKind kind;
  final String message;

  const AuthFailure(this.kind, this.message);

  factory AuthFailure.of(AuthFailureKind kind) => AuthFailure(kind, _copy[kind]!);

  static const Map<AuthFailureKind, String> _copy = {
    AuthFailureKind.cancelled: 'Sign-in was cancelled.',
    AuthFailureKind.invalidPhone:
        "That doesn't look like a valid mobile number.",
    AuthFailureKind.invalidCode: "That code isn't right. Check it and try again.",
    AuthFailureKind.codeExpired: 'That code has expired. Ask for a new one.',
    AuthFailureKind.tooManyAttempts:
        'Too many tries. Please wait a little and try again.',
    AuthFailureKind.network: "Couldn't reach the server. Check your connection.",
    AuthFailureKind.seatTaken:
        'Someone else has already registered for that. Choose another, or ask '
            'them to sign in.',
    AuthFailureKind.other: 'Something went wrong. Please try again.',
  };

  @override
  String toString() => message;
}

/// Everything sign-in and registration need from a backend.
///
/// Firebase implements it for the app; a local stand-in implements it for
/// tests and offline development, so nothing above this line knows which is
/// running.
abstract class AuthService {
  /// The signed-in user, now and whenever it changes. Emits first with the
  /// restored session (or null), which is what lets the app avoid flashing the
  /// sign-in screen at someone who is already signed in.
  Stream<AuthUser?> get userChanges;

  /// Google account picker. Throws [AuthFailure] with
  /// [AuthFailureKind.cancelled] if it is dismissed.
  Future<AuthUser> signInWithGoogle();

  /// Send a code to [phone], in international form (`+8801711204488`).
  Future<PhoneChallenge> sendPhoneCode(String phone);

  /// Check the code. Throws [AuthFailure] when it is wrong or expired.
  Future<AuthUser> confirmPhoneCode(PhoneChallenge challenge, String code);

  /// The seat this user registered for, or null if they have not registered.
  Future<UserProfile?> loadProfile(String uid);

  /// Register: store the profile and, for a pharmacy or delivery round, claim
  /// it so two people cannot hold the same one. Throws [AuthFailure] with
  /// [AuthFailureKind.seatTaken] if it is already claimed.
  Future<void> saveProfile(UserProfile profile);

  /// Give the seat up: delete this person's profile and, for a pharmacy or
  /// delivery round, its claim, together, so someone else can register for it.
  Future<void> releaseSeat(UserProfile profile);

  Future<void> signOut();
}
