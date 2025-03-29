## Common AMM Vulnerabilities

- [ ] **Missing slippage check**: Fails to implement minimum output or maximum input tolerance checks, allowing transactions to execute under adverse price conditions. This can lead to significant financial losses due to sandwich attacks or high volatility events.

- [ ] **Using spot price instead of TWAP**: Relying on current spot price rather than Time Weighted Average Price (TWAP) creates vulnerability to price manipulation. Single-block price manipulation attacks can exploit systems using spot pricing for critical operations.
  Reference: https://solodit.cyfrin.io/issues/m-04-price-manipulation-risk-in-gammavault-collateral-calculation-pashov-audit-group-none-gammaswap_2024-12-30-markdown

- [ ] **Lack of deadline parameter**: Without transaction deadline checks, pending transactions can be executed at a much later time when market conditions have significantly changed, potentially resulting in unfavorable trades for users.
  Reference: https://consensys.io/diligence/blog/2019/09/stop-using-soliditys-transfer-now/
  https://solodit.cyfrin.io/issues/m-04-lack-of-deadline-for-uniswap-amm-code4rena-asymmetry-finance-asymmetry-contest-git

- [ ] **Flash loan vulnerability**: AMMs can be exploited via flash loans if price calculations aren't properly protected. Flash loans allow attackers to manipulate pool balances temporarily, extracting value through arbitrage.
  Reference: https://medium.com/immunefi/hack-analysis-saddle-finance-april-2022-f2bcb119f38

- [ ] **Improper integration with Uniswap v3/v4/v2**: Integration issues include improper callback handling, incorrect tick calculations, or mismanagement of concentrated liquidity positions. These can lead to locked funds, economic losses, or manipulation vulnerabilities.
  Reference: https://dacian.me/exploiting-developer-assumptions#heading-uniswap-v3-integration-vulnerability

- [ ] **Rounding errors in calculations**: Mathematical operations that don't properly account for token decimals or rounding can lead to precision loss and exploitable conditions where attackers drain small amounts repeatedly.
  Reference: https://dacian.me/precision-loss-errors-in-defi

- [ ] **Reentrancy vulnerabilities**: AMM contracts that don't follow checks-effects-interactions pattern are vulnerable to reentrancy, particularly during swap operations when external tokens are involved.
  Reference: https://slowmist.medium.com/analysis-of-the-sui-fi-security-incident-52482786ba10

- [ ] **Price oracle manipulation**: AMMs often serve as price oracles for other protocols. Insufficiently secured price feeds can be manipulated through flash loans or sandwich attacks to exploit dependent protocols.
  Reference: https://samczsun.com/so-you-want-to-use-a-price-oracle/

- [ ] **Front-running protection failures**: Inadequate protection against MEV (Miner Extractable Value) allows transactions to be reordered, potentially leading to sandwich attacks that extract value from users' trades.
  Reference: https://blog.chain.link/chainlink-fair-sequencing-services-enabling-a-provably-fair-defi-ecosystem/

- [ ] **Delayed anti-MEV mechanism activation**: AMMs with anti-MEV mechanisms (like amAMM) that require a waiting period before activation lose protection during the initial high-volume trading period after pool creation.
  - **Technical details**: Some AMMs require K epochs (e.g., 24 hours) to pass before the first top bid can be set in their anti-MEV auction mechanism, leaving the pool vulnerable during its launch phase.
  - **Vulnerable pattern**: Pool states that transition from State A (no top bid, no next bid) to State B (with top bid) only after a mandatory waiting period, with no option to set an initial top bid at creation.
  - **Impact**: Loss of potential fee revenue and MEV protection during the highest trading volume period in a pool's lifecycle.
  - **Recommendation**: Allow assignment of an initial top bid during pool creation to enable immediate MEV protection.
  Reference: Found in AMMs implementing auction-based MEV protection with mandatory waiting periods.

- [ ] **Inconsistent AMM enablement checks**: Different parts of the code check different variables to determine if AMM features are enabled, leading to partial disablement where some functions respect admin overrides while others don't.
  - **Problem**: When admins try to disable an AMM manager through override settings, some functions ignore these overrides and continue using the manager's settings and paying them fees.
  - **Example**: Using `hookParams.amAmmEnabled` directly in swap functions instead of checking `getAmAmmEnabled()` which respects admin override settings.
  - **Impact**: Admins can't fully disable problematic AMM managers, who continue collecting fees even after being "disabled." Swap fees get stuck at whatever value was last set by the manager.
  - **Fix**: Always use the proper enablement check method (e.g., `getAmAmmEnabled()`) that respects all override settings.
  Reference: Found in AMM systems where different components handle feature toggling inconsistently.

### Unique issues in admin 
- [ ] **Stuck admin fees**: Fees allocated to admin accounts are added as liquidity but with no corresponding tracking mechanism (like mappings or NFT tokens). This creates a situation where the admin fees are permanently locked in the contract, as withdrawal functions typically check for ownership records that don't exist for these auto-generated positions.
  - **Technical details**: When users remove liquidity, a portion of fees is typically added back as liquidity for the admin account (e.g., `QuantAMMAdmin`). However, in implementations where this allocation doesn't create proper ownership records in mappings like `poolsFeeData`, any attempt to withdraw these funds will revert with errors like `WithdrawalByNonOwner`.
  - **Vulnerable pattern**: Functions like `_vault.addLiquidity()` adding admin fees without creating associated tracking records, while withdrawal functions like `removeLiquidityProportional()` check for non-zero `depositLength` in ownership mappings.
  - **Impact**: Permanent loss of admin fee revenue that should be retrievable by protocol governance.
  - **Recommendation**: Either mint proper ownership records when adding admin fee liquidity, or implement separate admin withdrawal functions that bypass ownership checks.
  Reference: This commonly occurs in AMMs where fees are auto-converted to LP positions for admins without creating the necessary accounting entries.

https://solodit.cyfrin.io/issues/fees-sent-to-quantammadmin-is-stuck-forever-as-there-is-no-function-to-retrieve-them-codehawks-quantamm-git

- [ ] **Centralized control without timelock**: Admin functions that can alter core parameters (fees, price curves, etc.) without timelock protection create single points of failure and potential for malicious or erroneous changes.
  Reference: 

- [ ] **Insufficient validation in parameter updates**: Admin functions that change critical parameters often lack proper bounds checking, potentially allowing parameters to be set to extreme values that break core functionality.
  Reference:

- [ ] **Reused state variables for different fee types**: Using the same state variable for different fee parameters creates ambiguity and potential misconfiguration. When different setter functions modify the same underlying storage variable, updating one fee unintentionally changes another.
  - **Technical details**: In some implementations, separate getter/setter functions like `setQuantAMMSwapFeeTake()` and `setQuantAMMUpliftFeeTake()` both modify the same state variable (e.g., `quantAMMSwapFeeTake`), causing one fee change to overwrite the other.
  - **Vulnerable pattern**: Multiple getter/setter functions accessing the same underlying state variable for conceptually different fees.
  - **Impact**: Potential fee misconfiguration leading to protocol revenue loss, where admin might not realize that changing one fee automatically changes another.
  - **Recommendation**: Use separate state variables for different fee types, ensuring each fee parameter has its own dedicated storage slot.
  Reference: Found in protocols where different fee types (e.g., swap fees vs. uplift fees) share underlying storage variables.
https://solodit.cyfrin.io/issues/quantammswapfeetake-used-for-both-getquantammswapfeetake-and-getquantammupliftfeetake-codehawks-quantamm-git

- [ ] **Incorrect weight calculation and normalization**: Implementation errors in weight clamping functions lead to incorrect weight distribution, potentially causing the sum of weights to exceed 1 (100%) or individual weights to exceed maximum constraints.
  - **Technical details**: Functions like `_clampWeights` that enforce minimum/maximum constraints on pool weights can miscalculate the normalization factor when they don't properly account for all relevant weights. For example, when `sumOtherWeights` only includes weights exceeding the maximum limit rather than all weights not at the minimum, the proportional adjustment becomes incorrect.
  - **Vulnerable pattern**: Incorrect collection of weight values during normalization, typically in code that attempts to maintain a sum of 1 (100%) while applying minimum/maximum constraints to individual weights.
  - **Impact**: Protocol breaking issue where core functionality relies on weights summing to exactly 1 (100%). Incorrect weights can lead to unfair value distribution, improper pricing, and significant economic loss.
  - **Recommendation**: Ensure that weight normalization logic accounts for all relevant weights in their sums, and validate that the final result maintains intended invariants (sum equals 1, no weight exceeds bounds).
  Reference: https://solodit.cyfrin.io/issues/out-of-bounds-array-access-in-_calculatequantammvariance-with-odd-number-of-assets-and-vector-lambda-codehawks-quantamm-git

### AMM Manager Fee Manipulation Issues

- [ ] **Fee bypass/capture vulnerability**: AMM managers can bypass fee distribution mechanisms to capture all fees by acting as proxies between users and protocols.
  - **Severity**: High impact, Medium likelihood
  - **Technical details**: Managers can set protocol swap fees to zero when executing their own swaps, then charge users a separate fee within their proxy contract, circumventing the intended fee sharing with protocol and referrers.
  - **Vulnerable pattern**: Systems where fee setters can dynamically change fees and also act as intermediaries for users' transactions.
  - **Impact**: Complete loss of protocol and referrer revenue, with all fees captured by the manager.
  - **Proof of concept**: Manager sets protocol fees to 0%, performs swaps through their proxy offering "competitive" rates (e.g., 1%), then resets protocol fees to maximum (e.g., 10%). The manager keeps all collected fees instead of sharing with protocol (typically 10%) and referrers (typically 10%).
  - **Recommendation**: Use the fee override or dynamic swap fee as the base for calculating all hook fees, ensuring protocol's revenue share regardless of manager actions.
  Reference: Observed in systems where AMM managers have control over fee parameters and can act as transaction proxies.

### Additional AMM Checks

- [ ] **Always validate the fee parameters**: Ensure all fee parameters have appropriate bounds checking and validation to prevent economic attack vectors.

- [ ] **Rounding issues lead to significant losses**: 
  - [ ] **Unchecked liquidity provision return values**: Failing to check the actual amounts of tokens used by AMMs during liquidity provision can lead to tokens getting locked in contracts.
    - **Technical details**: When providing liquidity to AMM pools, the actual amounts of tokens used often differ slightly (by 1-2 wei) from the approved amounts due to rounding in price ratio calculations. If these differences aren't handled, tokens remain in the contract with no way to withdraw them.
    - **Vulnerable pattern**: Functions that call `addLiquidity()` without checking its return values (`amountA`, `amountB`, `liquidity`), especially when the full token balance is transferred to the AMM without tracking leftovers.
    - **Impact**: Small amounts of tokens get locked with each liquidity provision, accumulating over time into significant locked funds.
    - **Recommendation**: Always check the return values from `addLiquidity()` calls and handle any differences between provided and actually used amounts. Either return unused tokens to users or account for them in the protocol.
    Reference: https://github.com/sherlock-audit/2024-08-cork-protocol-judging/issues/240 

### Oracle-Related Issues

- [ ] **Missing oracle updatability**: Lack of functionality to update or change the oracle address creates a single point of failure. If the oracle becomes compromised, deprecated, or outdated, there's no way to switch to a more secure or accurate alternative.
  - **Technical details**: AMMs relying on price oracles often hardcode oracle addresses or lack proper admin functions to update oracle references.
  - **Impact**: Protocol becomes permanently tied to potentially vulnerable or outdated price sources, reducing security and adaptability.
  - **Recommendation**: Implement secure admin functions with timelock protection to update oracle references when necessary.
  - **Real-world example**: Protocols like Synthetix have experienced issues when oracles became outdated, requiring emergency governance actions to mitigate problems.
  - **Reference**: https://medium.com/immunefi/the-importance-of-oracle-security-821c41f05090

- [ ] **Insufficient oracle price validation**: AMM contracts using external price oracles often fail to validate received price data, trusting the oracle implicitly. This can lead to transactions executed with stale, manipulated, or extreme price values.
  - **Technical details**: Missing sanity checks for price staleness, deviation limits, or reasonable bounds when consuming oracle data.
  - **Vulnerable pattern**: Functions that directly use oracle prices without validation checks like `require(block.timestamp - lastUpdateTime < maxAge)` or `require(newPrice < oldPrice * maxDeviation)`.
  - **Impact**: Malicious or malfunctioning oracles can cause significant economic damage through improper pricing.
  - **Recommendation**: Implement comprehensive price validation including freshness checks, deviation limits, and circuit breakers for extreme values.
  - **Reference**: https://blog.openzeppelin.com/secure-smart-contract-guidelines-the-dangers-of-price-oracles

- [ ] **Oracle manipulation through flash loans**: AMMs using single-source oracles or on-chain price references are vulnerable to manipulation through flash loans, where attackers can temporarily skew prices to exploit dependent protocols.
  - **Technical details**: AMMs that rely on spot prices from DEXs can be manipulated by large flash-loaned trades that temporarily imbalance pools.
  - **Impact**: Price manipulation can trigger unfair liquidations, allow attackers to borrow more than collateral value, or execute swaps at advantageous rates.
  - **Recommendation**: Use Time-Weighted Average Price (TWAP) oracles, multi-source oracles, or implement circuit breakers that limit price impact.
  - **Reference**: https://medium.com/amber-group/on-chain-price-oracles-a18f1fc5fdd0

- [ ] **Hardcoded or on-chain slippage parameters**: AMMs with slippage tolerance hardcoded in contracts or determined by on-chain mechanisms create vulnerabilities in volatile markets.
  - **Technical details**: Fixed slippage parameters (e.g., 0.5% or 1%) may be too restrictive during low volatility or too loose during high volatility, leading to either failed transactions or excessive slippage.
  - **Vulnerable pattern**: Using constants like `uint256 public constant MAX_SLIPPAGE = 100; // 1%` instead of user-configurable parameters.
  - **Impact**: During high volatility, users experience significant value loss; during low volatility, transactions may fail unnecessarily.
  - **Recommendation**: Allow users to specify their slippage tolerance per transaction while implementing reasonable bounds to prevent extreme values.
  - **Reference**: https://blog.1inch.io/how-to-avoid-high-slippage-in-defi-trading-96875c5a1f0c

- [ ] **Oracle data inconsistency checks**: AMMs using multiple oracle sources often fail to implement proper consistency checks between different price feeds, potentially using manipulated or incorrect prices.
  - **Technical details**: When using multiple price sources, protocols should validate consistency between them before executing price-sensitive operations.
  - **Vulnerable pattern**: Choosing the most favorable price from multiple oracles without checking for significant deviations between them.
  - **Impact**: Selection of manipulated or erroneous prices leading to economic exploits.
  - **Recommendation**: Implement deviation checks between multiple oracles and require consensus within acceptable bounds.
  - **Reference**: https://medium.com/coinmonks/implementing-robust-oracle-design-patterns-b5df6b62aac4

Here is a **checklist** for auditing an **Automated Market Maker (AMM)** based on the **Vertex Protocol Audit Report** findings:

### **Critical Issues: Immediate Risk**
- [ ] **Unit Conversion Errors**: Ensure proper precision handling in mathematical operations (`toInt()` vs. `fromInt()`) to prevent value manipulation.
- [ ] **Unauthorized Access Control**: Restrict access to sensitive functions (`updateStates` should only be callable by trusted contracts).
- [ ] **Settlement Calculation Errors**: Verify that profit/loss calculations only consider the user's portion and not the entire liquidity pool.
- [ ] **Double Conversion of Units in Swap**: Check for multiple conversions of quote amounts, which could allow fund manipulation.

### **High-Risk Issues: Fund Loss or Systemic Risks**
- [ ] **Incorrect Fee Calculations**: Ensure correct deduction of fees to prevent fund imbalances.
- [ ] **Unreachable Fee Dumping Function**: Ensure fee collection functions are callable to avoid locked funds.
- [ ] **Failed Deposits Not Refunding Users**: Ensure funds are returned if deposit transactions fail.
- [ ] **Socialized Losses Exceeding Insurance Cover**: Verify that socialization does not overcompensate losses.
- [ ] **Incorrect Borrow Rate Calculation**: Ensure borrow rate updates correctly as utilization ratio changes.
- [ ] **Variable Misuse in State Updates**: Confirm correct variables are used to update system states.

### **Medium-Risk Issues: Stability & Exploitability**
- [ ] **Improper Arithmetic Operations**: Check for signed integer handling to prevent underflow/overflow.
- [ ] **Slow Mode Transactions Exploits**: Ensure that only the sender can execute transactions in slow mode.
- [ ] **DumpFees Failure in PerpEngine**: Ensure that the collected fees are correctly transferred to fee accounts.
- [ ] **Incorrect LP State Updates**: Verify that LP state updates reflect actual cumulative values.
- [ ] **Mint/Burn LP Allows Negative Values**: Prevent unintended liquidity manipulation.
- [ ] **User-Controlled Pool Pricing**: Ensure initial pool pricing follows external oracle prices.
- [ ] **Incorrect Normalization Updates**: Ensure borrow and deposit normalization calculations are correct.
- [ ] **Incorrect Liquidation Status Checks**: Fix miscalculations in liquidation conditions.

### **Low-Risk Issues: Gas Optimization & Minor Bugs**
- [ ] **Health Group Update Errors**: Prevent unnecessary gas usage from large health group numbers.
- [ ] **Rounding Errors in Swap & Liquidity Functions**: Ensure correct rounding strategies for precision.
- [ ] **Time and Price Validation from Sequencer**: Validate external updates for time and price to prevent manipulation.
- [ ] **Zero Address Validation**: Prevent addition of zero addresses as valid contract parameters.

### **General Security Recommendations**
- [ ] **Code Redundancy**: Remove duplicate logic to reduce complexity and prevent inconsistencies.
- [ ] **Validate Token & Product IDs**: Ensure token and product addresses are valid before execution.
- [ ] **Unnecessary External Calls**: Use internal calls where applicable to save gas.
- [ ] **Improper Code Structure**: Optimize how functions are structured to improve execution efficiency.
- [ ] **Missing Event Emissions**: Add event logs for important actions (e.g., initialization, state updates).
- [ ] **Unbounded Transaction Execution**: Ensure limits on transaction execution loops to prevent DOS attacks.

Would you like a more detailed breakdown of any specific issue? 🚀