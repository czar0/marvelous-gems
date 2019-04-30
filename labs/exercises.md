# Exercises
Run `./scripts/script.sh listFunctions` for a complete list of the methods to use for those exercises.

## Exercise 1
A new owner, `alice`, accessing the blockchain network through `peer2`, would like to issue a new gem with ID `gem2`.

- How should the JSON input of the transaction look like? (feel free to choose colour and description)
- In which channel should the issuing procedure happen?
- What are the steps needed to allow `alice` to perform the issuing?
- Who will be able to see the content of the asset once the transaction completed?

Base format of the `Gem` JSON object:
```json
{
   "id":"string",
   "owner_id":"string",
   "colour":"string",
   "description":"string"
}
```

## Exercise 2
`gem2`'s owner, `alice` (`peer2`) would like to sell `gem2` to `bob` for `5000.30` coins. 
Once the transaction is done:

1. `bob` would like to see the current transaction connecting through is access peer, `peer3`.
2. a regulator (through `peer0`) should update the ownership of `gem2`.
3. now `bob` would like to see the complete information of the asset including the **previous owmers** list.

- How should the JSON input of the selling transaction look like?
- In which channel should the selling procedure happen?
- What are the steps `bob` needs to perform in order to complete _(1)_?
- How should the transaction of the update function for _(2)_ look like?
- What are the steps `bob` needs to perform in order to complete _(3)_?

Base format of the `Trade` JSON object:
```json
{
   "id":"string",
   "gem_id":"string",
   "seller":"string",
   "buyer":"string",
   "price":0.0
}
```