# Grouped purchase fixture selects a world below the Mining Laser requirement

Actual full CI740 reports three issues in groupedPurchasesUseItemIdentityAndRewardRowsCannotBeBought: Mining Laser is absent after Return, and both later reward-row checks have a balance other than 992000. The two reward items remain absent, and neither NOT FOR SALE message assertion fails. These observations do not establish a reward refusal or price defect.

The fixture chooses the first world with technology at least 10, currently G01-S003 Maran at TL10. Mining Laser costs 8000 native tenths and stores the zero-based requirement 10. Equipment.requiredTechnologyLevel converts that value to 11; equipmentAvailable compares it with the world's one-based level. The TL10 shop correctly refuses the laser before fitting or payment, so the expected 8000 debit never happens.

Select a world using the selected item's declared requiredTechnologyLevel. Keep the exact price, successful laser ownership and 992000 balance, both reward refusals and unchanged balance, and the NOT FOR SALE messages. No production policy, catalogue price, or unrelated test requires modification. The proposed fixture diagnosis remains provisional until the owner runs the affected method to PASS and independent review is clean.

The assigned change is limited to this one EquipmentGroupTests method and its paired PR note. The integrated XYZZY changes and other workers' production paths remain untouched. There is no external issue number; this note uses the task slug.
