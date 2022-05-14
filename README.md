# Curve <=> Aave Loan Manager

This project shows how to manage balances between Curve finance and Aave protocol. Usually yields on Curve were higher then on Aave (counting additional incentives) so it was profitable to put your crypto on Aave, then borrow stablecoins against it and transfer them to Curve 3pool.

The main contract is LoanManager and the user can interact with two main methods:
* ``` borrowAndStake() ``` which gets a loan on Aave => deposit stables to Curve.
* ``` unstakeAndRepay() ``` which withdraw from Curve => repay debt on Aave.

Contracts are designed in a way that assumes two actors: ``` the owner and the worker ```
The worker is a bot which scan blockchain state - Aave health factor, if health factor of the owner account is high then the bot can borrow stablecoins on behalf of the owner and stake them on Curve, make more profits.
If health factor is low the opposit is happening (bot source code is not included here). Bot (worker) is only able to call these two functions nothing less nothing more.

The owner is EOA which private keys are not expose in any way because they are not needed to constantly signing transactions as it is with the worker.
So division on both roles gives some level of security. This is rather proof of concept than complete project, but it gives a view how "money legos" could work. I was also interested with implementing bot using chainlink keepers, but when project was originaly created, keepers were not available on Polygon. 
