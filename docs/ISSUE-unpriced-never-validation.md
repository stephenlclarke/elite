# Preserve unpriced never-purchase hulls without free purchases

Accepted original specs retain zero price for never-purchasable hulls. Existing performance validation rejects it without policy context. Allowing zero indiscriminately would admit ordinary free purchases, and the existing quote has no unpriced refusal, so loader-only admission is insufficient.

Author decision: authoritative purchasePolicy=never with price zero means unpriced/not for sale. Other zero-price policies and all negative prices remain invalid. Newt fuel/jump/spool/missiles/facings and other integration policies are outside this patch.
