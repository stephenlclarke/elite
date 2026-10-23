# fix(stations): project station world without copying Commander

The station validation world reader copied the whole Commander receiver during
native advance, exhausting the stack in the retained original unit failure.
Read the stored world through its address instead, preserving the complete
validation policy and its lazy order.

Refs #137. The existing regression assertions are unchanged. Strict Swift
formatting and whitespace checks pass; independent source review and affected
unit completion remain pending. No native journey or usable release is claimed.
