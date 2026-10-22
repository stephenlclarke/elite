# Present commodities in their authored market order

Ledger M03.P03 / F10 specifies the authored commodity order: IDs9,8,10,2,7,12,13,15,14,1,4,5,0,11,6,3,16. The current market instead renders, clicks and navigates ascending commodity IDs. Those IDs also index cargo and live quotes, so reordering the underlying arrays would break their identity.

Add one display-position projection from the validated authoring table. Use it for rendered rows, pointer selection and only the market Up/Down selection branches. Keep selected commodity IDs stable through redraw and market mode changes, preserve existing bounded navigation, and leave prices, stock, transactions and all cargo arrays unchanged.

Equipment price/TL discrepancies remain the explicit U03 precedence decision. This display change does not rebalance those values, add stock replenishment or invent a market-epoch framework.
