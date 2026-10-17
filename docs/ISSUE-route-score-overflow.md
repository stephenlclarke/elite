# Score supported large market quantities without integer overflow

CR-08 includes the actual auto-trade route selector. Selling a supported maximum cargo quantity enlarges market stock; route scoring multiplies that stock by an integer profit before converting the result to Double. The intermediate Int product can trap even though the loaded Commander is valid.

Convert the score operands before multiplying and accumulate directly in Double. Preserve route risk, distance, export ordering, cash limits and all actual transaction quantities. The separate ProfitScan repair remains owned by the mission/economy worker. See the [repair handoff](PR-route-score-overflow.md).
