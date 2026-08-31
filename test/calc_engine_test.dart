import 'package:flutter_test/flutter_test.dart';
import 'package:teashop_manager/utils/calc_engine.dart';

void main() {
  void type(CalcEngine e, String keys) {
    for (final k in keys.split('')) {
      switch (k) {
        case '+':
        case '-': // stands in for the − key
          e.setOperator(k == '-' ? '−' : '+');
        case '*':
          e.setOperator('×');
        case '/':
          e.setOperator('÷');
        case '=':
          e.equals();
        default:
          e.inputDigit(k);
      }
    }
  }

  test('adds a simple expression', () {
    final e = CalcEngine();
    type(e, '12+30=');
    expect(e.display, '42');
    expect(e.value, 42);
    expect(e.showTick, isTrue);
  });

  test('chains operators left to right', () {
    final e = CalcEngine();
    type(e, '2+3*4=');
    expect(e.display, '20'); // (2+3)*4
  });

  test('subtraction and division', () {
    final e = CalcEngine();
    type(e, '100-40=');
    expect(e.display, '60');
    e.clear();
    type(e, '9/2=');
    expect(e.display, '4.5');
  });

  test('divide by zero surfaces an error and blocks adding', () {
    final e = CalcEngine();
    type(e, '5/0=');
    expect(e.display, 'Error');
    expect(e.canAdd, isFalse);
    expect(e.showTick, isFalse);
  });

  test('typing a digit after = starts a fresh calculation', () {
    final e = CalcEngine();
    type(e, '8+2=');
    expect(e.showTick, isTrue);
    e.inputDigit('5');
    expect(e.display, '5');
    expect(e.showTick, isFalse);
  });

  test('percent takes a share of the running total', () {
    final e = CalcEngine();
    type(e, '200');
    e.setOperator('×');
    e.inputDigit('1');
    e.inputDigit('0'); // "10"
    e.percent(); // 10% of 200 => 20
    e.equals(); // 200 × 20
    expect(e.value, 4000);
  });

  test('backspace only edits the current entry', () {
    final e = CalcEngine();
    type(e, '123');
    e.backspace();
    expect(e.display, '12');
    type(e, '=');
    e.backspace(); // ignored after =
    expect(e.display, '12');
  });

  test('clear resets everything', () {
    final e = CalcEngine();
    type(e, '7+7=');
    e.clear();
    expect(e.display, '0');
    expect(e.history, '');
    expect(e.canAdd, isFalse);
  });

  test('a lone number then = is addable', () {
    final e = CalcEngine();
    type(e, '250=');
    expect(e.value, 250);
    expect(e.showTick, isTrue);
  });

  test('only one decimal point per number', () {
    final e = CalcEngine();
    type(e, '1');
    e.inputDigit('.');
    e.inputDigit('.');
    e.inputDigit('5');
    expect(e.display, '1.5');
  });

  test('format trims trailing zeros', () {
    expect(CalcEngine.format(5), '5');
    expect(CalcEngine.format(5.5), '5.5');
    expect(CalcEngine.format(5.50), '5.5');
    expect(CalcEngine.format(0), '0');
  });
}
