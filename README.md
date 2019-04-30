# Hyperledger Fabric: Multi-channel demo

Hyperledger Fabric V1 introduces an interesting feature aimed at guaranteeing confidentiality of sensitive data between peers of the same network. The result is obtained not using encryption or obfuscation mechanisms but rather segregating data and keep that information available only to targeted peers in the network. One of the main advantages of this approach is that it does not allow unauthorized peers to store sensitive data in their local ledger. The reason behind this choice is the following: even if encrypted, sensitive data would be still exposed to untrusted (or even worse, malicious) peers which could eventually discover the secret key used in the process or use brute force to finally obtain readable data.

This CLI Demo offers a good example of multi-channel communication between peers.

# Marvelous Gems!

## Description of the network
![network topology](assets/img/network.png "Network topology")

The configuration of the network is rather basic and it is the following:

### Organizations
The network is composed of a single organization: `org1.example.com`.

### Members
1.  `ca0` - Certificate Authority for all the members of `org1.example.com`.
2.	`orderer` - The only ordered of the network and having purely a technical function (only ordering). A bigger and scaled network would usually require 2 or more orderers which should first reach consensus based on specific ordering algorithms and then create a new block to deliver to committers.
3.	`peer0` - Having role of unique endorser in the network. It is responsible to sign proposal transactions whether they respect the defined endorsement policy. It is also in charge to perform additional multi-channels operations.
4.	`peer1` - Committing peer.
5.	`peer2` - Committing peer.
6.	`peer3` - Committing peer.

### Channels

**private**

![private channel](assets/img/private.png "PRIVATE channel topology")

It is one-to-one typology channel between a peer and its endorser. It holds the most sensitive information related to a peer, like balance, ownership on gems, etc.

**trading**

![trading channel](assets/img/trading.png "TRADING channel topology")

It is created by 2 peers involved in a transaction of transferring ownerships on gems.

**sharing**

![sharing channel](assets/img/sharing.png "SHARING channel topology")

It represents the public channel which all the informative but not sensitive is shared in. It includes all the peers of the network.

**Note:** Even if not specified, all the mentioned channels above always include endorsers, ca and orderers.
To define even better the concept of data segregation, each typology of channel is provided with its own customized smart-contract which has also a different datamodel. Note that is not mandatory to use different chaincodes to obtain data segregation.

![channels](assets/img/channels.png "Full overview of the network with channels")

## Description of the scenario
The presented demo shows a generic lifecycle of a gem: creation, trading and publishing updates.

The scenario can be defined basically in two macro operations: issuing a gem and trading and gem.

### Issuing a gem

1.	Invoke to issue a gem on the `private` channel (peer1)
2.	Invoke to approve a gem on the `private` channel (peer0)
3.	Query to retrieve information about the gem on the `private` channel (peer1)
4.	Other peers not in the `private` channel cannot see the information stored if they try to query it (peer2)
5.	Invoke to create a gem on the `sharing` channel (peer0)

### Trading a gem

1.	Invoke to transfer from John (peer1) to Jane (peer2) on the `trading` channel (peer1)
2.	Query to retrieve the transaction on the `trading` channel (peer2)
3.	Other peers not in the `trading` channel cannot see the information stored if they try to query it (peer3)
4.	Invoke to update the balance of a gem on the `private` channel (peer0)
5.	Invoke to update available quantity of gem on the `sharing` channel (peer0)

## Smart-contracts
### private-cc
```go
type Gem struct {
	ID             string    `json:"id"`
	OwnerID        string    `json:"owner_id"`
	PreviousOwners []string  `json:"previous_owners,omitempty"`
	Colour         string    `json:"colour"`
	Description    string    `json:"description,omitempty"`
	Status         string    `json:"status,omitempty"`
	CreatedAt      time.Time `json:"created_at,omitempty"`
	UpdatedAt      time.Time `json:"updated_at,omitempty"`
}

const (
	GEM_ISSUED    = "ISSUED"
	GEM_CERTIFIED = "CERTIFIED"
)
```

### trading-cc
```go
type Trade struct {
	ID        string    `json:"id"`
	GemID     string    `json:"gem_id"`
	Buyer     string    `json:"buyer"`
	Seller    string    `json:"suller"`
	Price     float64   `json:"price"`
	Timestamp time.Time `json:"timestamp,omitempty"`
}
```

### sharing-cc
```go
type Gem struct {
	ID          string    `json:"id"`
	Colour      string    `json:"colour"`
	Description string    `json:"description"`
	Price       float64   `json:"price"`
	CreatedAt   time.Time `json:"created_at,omitempty"`
	UpdatedAt   time.Time `json:"updated_at,omitempty"`
}
```

## Setting up the network
Follow the steps below to start up the network, initialize channels and have a first try of the demo:
1. Run the `install` script
```bash
./scripts/install.sh
```
It will pull all th docker images needed to execute the demo.
2. Open your terminal, navigate to the root of the project and run the command:
```bash
./scripts/start.sh
```
3.	Wait few seconds and then run in the same tab: 
```bash
docker exec -it cli bash
```
It will run a container in interactive mode that gives us the ability to control the peers. It is configured to hold all the certificates necessary to perform all the operations. Using a certificate of a peer instead of another, it will emulate that specific one. That is the reason why it is important to specify in front of each invoke which peer identity to use.

4.	From the docker container terminal, run the initial configuration script:
```bash
./scripts/script.sh init
```
It will do the following:
-	Create the 3 channels
-	Peer0 and peer1 join `private` channel
-	Peer0, peer1, peer2 join `trading` channel
-	Peer0, peer1, peer2 and peer3 join `sharing` channel
-	Install `private-cc` chaincode in peer0 and peer1
-	Install `trading-cc` chaincode in peer0, peer1 and peer2
-	Install `sharing-cc` chaincode in peer0, peer1, peer2 and peer3
-	Instantiate all the chaincodes only on peer0

The network is now setup and there will be only containers running the chaincode on peer0. The chaincode containers for peer1 and peer2 will be started as soon as you do a query or invoke on these peers (in lazy-mode).

## Running invokes and queries
From within the `cli` container you can manually run invokes and queries (and other operations listed below).

To run a **query** function with:
```bash
./scripts/script.sh query [PEER_NR] [CHANNEL] [CHAINCODE] [KEY]
```
e.g.
```bash
./scripts/script.sh query 0 private private-cc gem1
```
This will run a query from `peer0` (that means, using its own certificates) on `private` channel, for `private-cc` chaincode of key `gem1`.

To run a **invoke** function with:
```bash
./scripts/script.sh invoke [PEER_NR] [CHANNEL] [CHAINCODE] [FUNCTION] [ARGS]
```
e.g. with single composite input
```bash
./scripts/script.sh invoke 1 private private-cc issueGem '{"id":"gem1","owner_id":"john","colour":"red","description":"shining!"}'
```
This will run an `invoke` from `peer1` on `private` channel, for `private-cc` chaincode, using as parameters the function `issueGem` and as args a stringified json containing the gem to issue.

Some useful tools could help to:

Create and validate the JSON input (step: 1. Validate, 2. Minify): [JSON Formatter and Validator](https://jsonformatter.org/)

e.g. with multiple inputs
```bash
./scripts/script.sh invoke 0 sharing private-cc updateOwnership gem1 jane
```
This will run an `invoke` from `peer0`, on `private` channel, for `private-cc` chaincode, to `updateOwnership` of a gem, `gem1`, to its new owner, `jane`.

Here below the complete list of all the commands included in `script.sh`:
```bash
    init                                                        Run the first initialisation of the network
    demo                                                        Run the interactive demo described in the README
    listFunctions                                               Show a list of the available functions divided by smart-contract
    setPeer [PEER_NR]                                           Set credentials as peer [PEER_NR]
    createChannel [CHANNEL]                                     Create a new channel with [CHANNEL]
    joinChannel [PEER_NR] [CHANNEL]                             Add peer [PEER_NR] to [CHANNEL]
    installChaincode [PEER_NR] [CHAINCODE]                      Install [CHAINCODE] on peer [PEER_NR]
    instantiateChaincode [PEER_NR] [CHANNEL] [CHAINCODE]        Instantiate [CHAINCODE] on peer [PEER_NR] in [CHANNEL] channel
    query [PEER_NR] [CHANNEL] [CHAINCODE] [KEY]                 Query by [KEY] on [CHANNEL] and [CHAINCODE] with [PEER_NR]
    invoke [PEER_NR] [CHANNEL] [CHAINCODE] [FUNCTION] [ARGS]    Invoke [FUNCTION] with [ARGS] on [CHANNEL] and [CHAINCODE] with [PEER_NR]
```
## Clean the containers
The following script will remove all the containers related to Hyperledger Fabric V1, including chaincode containers. Furthermore, it will clean all orphan and incomplete docker images.

Run with:
```bash
./scripts/clean.sh
``` 
## Demo step-by-step

**Note:** Each command is preceded by a line of configuration with contains the credentials of each peer executing the specific operation.

If you do not want to copy-and-paste command by command into the terminal, there is an easy and interactive way to run this demo with one single command:
```bash
./scripts/script.sh demo
```

### Issuing a gem
Invoke to issue a gem on the `private` channel (peer1):
```bash
./scripts/script.sh invoke 1 private private-cc issueGem '{"id":"gem1","owner_id":"john","colour":"red","description":"shining!"}'
```
Invoke to certify a gem on the `private` channel (peer0):
```bash
./scripts/script.sh invoke 0 private private-cc certifyGem gem1
```
Query to retrieve information about the gem on the `private` channel (peer1):
```bash
./scripts/script.sh query 1 private private-cc gem1
```
Other peers not in the `private` channel cannot see the information stored if they try to query it (peer2):
```bash
./scripts/script.sh query 2 private private-cc gem1
```
Invoke to create a gem on the `sharing` channel (peer0):
```bash
./scripts/script.sh invoke 0 sharing sharing-cc createGem '{"id":"gem1","colour":"red","descrption":"shining!","price":1500.34}'
```

### Trading a gem
Invoke to transfer the ownership of the gem from John (peer1), the seller, to Jane (peer2), the buyer, on the `trading` channel (peer1)
```bash
./scripts/script.sh invoke 1 trading trading-cc createTrade '{"id":"tx1","seller":"john","buyer":"jane","price":1500.34}'
```
Query to retrieve the trade information on the `trading` channel (peer2):
```bash
./scripts/script.sh query 2 trading trading-cc tx1
```
Other peers not in the `trading` channel cannot see the information stored if they try to query it (peer3):
```bash
./scripts/script.sh query 3 trading trading-cc tx1
```
Invoke to update the ownership of a gem on the `private` channel (peer0):
```bash
./scripts/script.sh invoke 0 private private-cc updateOwnership gem1 jane
```
Note: Take in account that, a symmetrical operation to create/update the balance on the `private` channel between peer0 and peer2 should be done as well, but it is not included in this demonstration (channel missing).

Invoke to update the price of gem on the `sharing` channel (peer0):
```bash
./scripts/script.sh invoke 0 sharing sharing-cc updateGemPrice 2000.40
```

### Get all the gems
Query to retrieve all the gems on the `sharing` channel (peer3):
```
./scripts/script.sh query 3 sharing sharing-cc getAllGems available
```

## Troubleshooting
- Do NOT use the docker detachment mode (`-d`) together with `--force recreate`. So go only for `docker-compose up -d` and use the `./scripts/clean.sh` to clean your environment.
- If you see './scripts/script.sh: line 219: peer: command not found' this probably means you're running the script from outside of the container. First run `docker exec -it cli bash` and start the script from in there.
- While running `./scripts/script.sh init` inside the `cli` container you get `Error endorsing chaincode: rpc error: code = Unknown desc = Error starting container: API error (404): {"message":"network gemlifecycle_default not found"}` and your `dev-` container stopped. More likely is due to a wrong configuration if the `CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE` variable. Go to `network/base/peer-base.yaml` and be sure to have `- CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=ROOTFOLDER_default`, where `ROOTFOLDER` is the name of your main directory, e.g. `gem-lifecycle` in case you cloned directly with git. 