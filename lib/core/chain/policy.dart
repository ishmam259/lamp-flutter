// Fabric-style endorsement policy parser and evaluator.
// Supports AND(...), OR(...), OutOf(n, ...) and 'MSP.role' leaf principals.

abstract class PolicyNode {
  bool evaluate(Set<String> signers);
}

class LeafNode extends PolicyNode {
  final String msp;
  final String role;

  LeafNode(this.msp, this.role);

  @override
  bool evaluate(Set<String> signers) => signers.contains(msp);
}

class AndNode extends PolicyNode {
  final List<PolicyNode> children;

  AndNode(this.children);

  @override
  bool evaluate(Set<String> signers) {
    // AND of an empty conjunction is vacuously true in pure logic, but in an
    // endorsement policy that means "anyone can write" — never the intent.
    // Treat empty children as a malformed policy and refuse.
    if (children.isEmpty) return false;
    return children.every((c) => c.evaluate(signers));
  }
}

class OrNode extends PolicyNode {
  final List<PolicyNode> children;

  OrNode(this.children);

  @override
  bool evaluate(Set<String> signers) => children.any((c) => c.evaluate(signers));
}

class OutOfNode extends PolicyNode {
  final int n;
  final List<PolicyNode> children;

  OutOfNode(this.n, this.children);

  @override
  bool evaluate(Set<String> signers) =>
      children.where((c) => c.evaluate(signers)).length >= n;
}

class PolicyParser {
  static List<String> _splitArgs(String src) {
    final out = <String>[];
    int depth = 0;
    bool quoted = false;
    int start = 0;

    for (int i = 0; i < src.length; i++) {
      final c = src[i];
      if (c == "'") {
        quoted = !quoted;
      } else if (!quoted && c == '(') {
        depth++;
      } else if (!quoted && c == ')') {
        depth--;
      } else if (!quoted && c == ',' && depth == 0) {
        out.add(src.substring(start, i));
        start = i + 1;
      }
    }
    out.add(src.substring(start));
    return out.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  static PolicyNode parse(String src) {
    final s = src.trim();
    if (s.isEmpty) throw const FormatException('Empty policy expression.');

    final open = s.indexOf('(');

    if (open > 0 && s.endsWith(')')) {
      final head = s.substring(0, open).trim().toUpperCase();
      final body = s.substring(open + 1, s.length - 1);

      if (head == 'AND') {
        final kids = _splitArgs(body).map(parse).toList();
        if (kids.isEmpty) throw FormatException('AND() requires at least one principal: $src');
        return AndNode(kids);
      }
      if (head == 'OR') {
        final kids = _splitArgs(body).map(parse).toList();
        if (kids.isEmpty) throw FormatException('OR() requires at least one principal: $src');
        return OrNode(kids);
      }
      if (head == 'OUTOF') {
        final parts = _splitArgs(body);
        if (parts.length < 2) {
          throw FormatException('OutOf requires a count and at least one principal: $src');
        }
        final n = int.tryParse(parts[0]);
        if (n == null) throw FormatException('OutOf needs numeric count: $src');
        if (n < 1 || n > parts.length - 1) {
          throw FormatException('OutOf count $n is out of range for ${parts.length - 1} principals: $src');
        }
        return OutOfNode(n, parts.sublist(1).map(parse).toList());
      }
      throw FormatException('Unknown policy operator "$head" in $src');
    }

    // A leaf must look like 'MSP.role'. Without the dot we cannot tell a
    // misconfigured principal apart from a valid one, so refuse.
    final leaf = s.replaceAll("'", '');
    final dot = leaf.lastIndexOf('.');
    if (dot <= 0 || dot == leaf.length - 1) {
      throw FormatException('Policy leaf must be "MSP.role", got "$leaf"');
    }
    return LeafNode(leaf.substring(0, dot), leaf.substring(dot + 1));
  }

  static bool satisfies(String policyExpr, Iterable<String> endorserMsps) {
    if (policyExpr.trim().isEmpty) return true;
    try {
      final ast = parse(policyExpr);
      return ast.evaluate(endorserMsps.toSet());
    } catch (_) {
      // Malformed policy → deny. Fabric would refuse to instantiate such a
      // chaincode at deploy time, so this is the right default at runtime.
      return false;
    }
  }
}
