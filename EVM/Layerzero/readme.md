1. Make sure the layerzero fees is not hardcoded, but rather calculated based on the current gas price and the destination chain.
2. There is a function to get the gas price of performing a cross-chain transfer, this function should be always public and not private.
3. The refund address should be set by the user not by the contract.
4. Refund gas should be going to the the correct address. 