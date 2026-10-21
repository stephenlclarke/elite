# Alien missiles must exceed standard speed and damage by 25%

FR-025 requires alien missiles to be 25% faster and inflict 25% more damage than standard missiles. The standard runtime profile uses speed 792 and damage 250. Alien seekers already travel at 990, but their damage of 160 is below standard. The salvage specification repeats both alien values, allowing it to drift from runtime behavior.

Derive the alien profile from standard speed and damage at a factor of 1.25 and make the salvage specification read those authoritative values. Preserve guidance, one-activation ECM resistance, range, lifetime and ammunition behavior. See [implementation and validation limits](PR-alien-missile-relative-strength.md).
