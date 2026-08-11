/// A small value type that represents money using integer minor units
/// (paisa), as recommended by the product spec to avoid floating point
/// drift in financial calculations.
class Money implements Comparable<Money> {
  final int paisa;

  const Money(this.paisa);

  const Money.zero() : paisa = 0;

  Money.fromMajor(double amount) : paisa = (amount * 100).round();

  Money fromRupees(double rupees) => Money((rupees * 100).round());

  bool get isZero => paisa == 0;
  bool get isNegative => paisa < 0;
  bool get isPositive => paisa > 0;

  double get major => paisa / 100;

  Money operator +(Money other) => Money(paisa + other.paisa);
  Money operator -(Money other) => Money(paisa - other.paisa);
  Money operator *(int factor) => Money(paisa * factor);
  Money operator ~/(int divisor) => Money(paisa ~/ divisor);

  Money abs() => Money(paisa.abs());
  Money negate() => Money(-paisa);

  @override
  int compareTo(Money other) => paisa.compareTo(other.paisa);

  @override
  bool operator ==(Object other) =>
      other is Money && other.paisa == paisa;

  @override
  int get hashCode => paisa.hashCode;

  @override
  String toString() => 'Money($paisa paisa)';
}
