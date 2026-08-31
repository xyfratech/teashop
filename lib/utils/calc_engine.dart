/// A tiny left-to-right 4-function calculator engine, kept free of Flutter so
/// it can be unit tested directly.
class CalcEngine {
  double? _acc; // running total
  String? _op; // pending operator: + − × ÷
  String _entry = ''; // digits being typed
  String _history = ''; // faint line shown above the result
  bool _justEvaluated = false;

  String get history => _history;

  bool get justEvaluated => _justEvaluated;

  /// The number currently in focus (typed entry, else the accumulator).
  double get value {
    if (_entry.isNotEmpty) return double.tryParse(_entry) ?? 0;
    return _acc ?? 0;
  }

  /// What the big display should read.
  String get display => _entry.isNotEmpty ? _entry : format(_acc ?? 0);

  bool get canAdd => !value.isNaN && value > 0;

  /// True once `=` has resolved a positive result — the moment the `=` key
  /// should present itself as a tick.
  bool get showTick => _justEvaluated && canAdd;

  static String format(double v) {
    if (v.isNaN) return 'Error';
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toStringAsFixed(0);
    var s = v.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  static double _apply(double a, double b, String op) {
    switch (op) {
      case '+':
        return a + b;
      case '−':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        return b == 0 ? double.nan : a / b;
      default:
        return b;
    }
  }

  void inputDigit(String d) {
    if (_justEvaluated) {
      _acc = null;
      _op = null;
      _history = '';
      _entry = '';
      _justEvaluated = false;
    }
    if (d == '.') {
      if (_entry.contains('.')) return;
      _entry = _entry.isEmpty ? '0.' : '$_entry.';
      return;
    }
    if (_entry == '0') _entry = '';
    if (_entry.replaceAll(RegExp(r'[^0-9]'), '').length >= 12) return;
    _entry += d;
  }

  void setOperator(String op) {
    _justEvaluated = false;
    if (_acc != null && _op != null && _entry.isNotEmpty) {
      _acc = _apply(_acc!, double.parse(_entry), _op!);
    } else if (_entry.isNotEmpty) {
      _acc = double.parse(_entry);
    } else {
      _acc ??= 0;
    }
    _op = op;
    _entry = '';
    _history = '${format(_acc!)} $op';
  }

  void equals() {
    if (_op != null && _acc != null) {
      final b = _entry.isNotEmpty ? double.parse(_entry) : _acc!;
      _history = '${format(_acc!)} $_op ${format(b)} =';
      _acc = _apply(_acc!, b, _op!);
      _op = null;
      _entry = '';
      _justEvaluated = true;
    } else if (_entry.isNotEmpty) {
      _acc = double.parse(_entry);
      _entry = '';
      _justEvaluated = true;
    }
  }

  void percent() {
    _justEvaluated = false;
    final v = _entry.isNotEmpty ? (double.tryParse(_entry) ?? 0) : (_acc ?? 0);
    final result = (_acc != null && _op != null) ? _acc! * v / 100 : v / 100;
    _entry = format(result);
  }

  void backspace() {
    if (_justEvaluated) return;
    if (_entry.isNotEmpty) {
      _entry = _entry.substring(0, _entry.length - 1);
    }
  }

  void clear() {
    _acc = null;
    _op = null;
    _entry = '';
    _history = '';
    _justEvaluated = false;
  }
}
