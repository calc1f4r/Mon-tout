1. Download the certora cli and setup the env and api keys
2. in the root create a folder called certora
3. create a folder called specs in the certora folder
4. create a folder called confs in the certora folder 


> PS specs contains the rules and invariants and the confs contains the configuration files like which contracts to check and which rules to check

```
{
    "files": [
        "src/Token.sol"
    ],
    "verify": "Token:test/certora/spec/tests.spec",
    "packages": [
        "@openzeppelin=lib/openzeppelin-contracts"
    ],
    "solc": "solc",
    "optimistic_loop": true,
    "loop_iter": "3",
    "rule_sanity": "basic"
}
``` 
conf 
