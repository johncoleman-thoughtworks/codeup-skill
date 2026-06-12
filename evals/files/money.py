from dataclasses import dataclass


@dataclass(frozen=True)
class Money:
    """A value object for currency amounts, stored in minor units (cents)."""

    cents: int
    currency: str

    def add(self, other: "Money") -> "Money":
        self._assert_same_currency(other)
        return Money(self.cents + other.cents, self.currency)

    def subtract(self, other: "Money") -> "Money":
        self._assert_same_currency(other)
        return Money(self.cents - other.cents, self.currency)

    def _assert_same_currency(self, other: "Money") -> None:
        if self.currency != other.currency:
            raise ValueError(f"currency mismatch: {self.currency} vs {other.currency}")
