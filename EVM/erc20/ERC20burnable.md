# Anyone can burn **DecentralizedStableCoin** tokens with `burnFrom` function

### Severity
Medium Risk

## Summary

Anyone can burn `DSC` tokens with [`burnFrom`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/0a25c1940ca220686588c4af3ec526f725fe2582/contracts/token/ERC20/extensions/ERC20Burnable.sol#L35-L38) function inherited of **OZ ERC20Burnable** contract

## Vulnerability Details

In the **DecentralizedStableCoin** contract the `burn` function is `onlyOwner` and is used by **DSCEngine** contract, which is the owner of **DecentralizedStableCoin** contract

## Impact

The tokens can be burned with `burnFrom` function bypassing the `onlyOwner` modifier of the `burn` functions

## Recommendations

Block the `burnFrom` function of **OZ ERC20Burnable** contract 


So erc20 Burnale have a `burnFrom` function that allows anyone to burn tokens from any address, which can lead to loss of funds if not properly managed. 

This is a public function 
```solidity
     */
    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}
```