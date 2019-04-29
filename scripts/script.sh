#!/bin/bash

: ${TIMEOUT:="60"}
COUNTER=0
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
CHANNELS_PATH="$(pwd)/channels"

help() {
    local help="
        List of available commands:

        init                                                        : Run the first initialisation of the network
        demo                                                        : Run the interactive demo described in the README
        listFunctions                                               : Show a list of the available functions divided by smart-contract
        setPeer [PEER_NR]                                           : Set credentials as peer [PEER_NR]
        createChannel [CHANNEL]                                     : Create a new channel with [CHANNEL]
        joinChannel [PEER_NR] [CHANNEL]                             : Add peer [PEER_NR] to [CHANNEL]
        installChaincode [PEER_NR] [CHAINCODE]                      : Install [CHAINCODE] on peer [PEER_NR]
        instantiateChaincode [PEER_NR] [CHANNEL] [CHAINCODE]        : Instantiate [CHAINCODE] on peer [PEER_NR] in [CHANNEL] channel
        query [PEER_NR] [CHANNEL] [CHAINCODE] [KEY]                 : Query by [KEY] on [CHANNEL] and [CHAINCODE] with [PEER_NR]
        invoke [PEER_NR] [CHANNEL] [CHAINCODE] [FUNCTION] [ARGS]    : Invoke [FUNCTION] with [ARGS] on [CHANNEL] and [CHAINCODE] with [PEER_NR]  
    "
    echo "$help"
}

listFunctions () {
    local functions="List of available functions per chaincode:
    =====================================
    CHAINCODE: private-cc

    issueGem [JSON]                      : Create a new gem [JSON] and set the status to ISSUED
    certifyGem [GEM_ID]                  : Set the status of the gem as CERTIFIED
    updateOwnership [GEM_ID] [OWNER_ID]  : Transfer ownership to new [OWNER_ID] and move the previous owner in the list
    =====================================
    CHAINCODE: trading-cc

    createTrade [JSON]                   : Create a transaction [JSON] with the details of the transfer
    ======================================
    CHAINCODE: sharing-cc

    createGem [JSON]                     : Add a new gem [JSON] in the showcase
    updateGemPrice [GEM_ID] [PRICE]      : Update the [PRICE] of a gem [GEM_ID]
    getAllGems available                 : Return all the available gems in the marketplace
    "
    
    echo "$functions"
}

gracefulExit () {
    printf "\n\nCTRL-C detected. Exiting...\n"
    # reenable tty echo
    stty icanon echo echok
    exit 1
}

trap gracefulExit INT

verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
                echo "================== ERROR !!! FAILED to execute script =================="
		echo
   		exit 1
	fi
}

setGlobals () {
	CORE_PEER_LOCALMSPID="Org1MSP"
    CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer$1.org1.example.com/tls/server.crt
    CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer$1.org1.example.com/tls/server.key
	CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer$1.org1.example.com/tls/ca.crt
	CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
	CORE_PEER_ADDRESS=peer$1.org1.example.com:$((7 + $1))051
	env | grep CORE
}

# Set OrdererOrg.Admin globals
setOrdererGlobals() {
  CORE_PEER_LOCALMSPID="OrdererMSP"
  CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
  CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp
}

createChannel() {
    CHANNEL_NAME=$1

    setGlobals 0

    echo "===================== Going to create Channel \"$CHANNEL_NAME\"  ===================== "

    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f $CHANNELS_PATH/$CHANNEL_NAME/${CHANNEL_NAME}_tx.pb >&fabric-v1.log
	else
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f $CHANNELS_PATH/$CHANNEL_NAME/${CHANNEL_NAME}_tx.pb --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&fabric-v1.log
	fi

	res=$?
	cat fabric-v1.log
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

fetchChannel() {
    CHANNEL_NAME=$1

    setOrdererGlobals

    echo "===================== Going to fetch the most recent config block for channel \"$CHANNEL_NAME\"  ===================== "

    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
        peer channel fetch config $CHANNEL_NAME.block -o orderer.example.com:7050 -c $CHANNEL_NAME --cafile $ORDERER_CA >&fabric-v1.log
    else
        peer channel fetch config $CHANNEL_NAME.block -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA >&fabric-v1.log
    fi

    res=$?
    cat fabric-v1.log
    verifyResult $res "Channel creation failed"
    echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
    echo
}

updateAnchorPeers() {
    PEER=$1
    CHANNEL_NAME=$2

    setGlobals $PEER

    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
        peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f $CHANNELS_PATH/$CHANNEL_NAME/${CORE_PEER_LOCALMSPID}_anchors_tx.pb >&fabric-v1.log
    else
        peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f $CHANNELS_PATH/$CHANNEL_NAME/${CORE_PEER_LOCALMSPID}_anchors_tx.pb --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&fabric-v1.log
    fi

    res=$?
    cat log.txt
    verifyResult $res "Anchor peer update failed"
    echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
    sleep 5
    echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
    PEER=$1
    CHANNEL_NAME=$2

    setGlobals $PEER

    peer channel join -b $CHANNEL_NAME.block >&fabric-v1.log
	res=$?
	cat fabric-v1.log

	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=$(expr $COUNTER + 1)
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep 2
		joinWithRetry $PEER $CHANNEL
	else
		COUNTER=1
	fi
        verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the channel $2"
}

joinChannel () {
    PEER=$1
    CHANNEL_NAME=$2
    echo "===================== Joining \"$CHANNEL_NAME\" on Peer$PEER  ===================== "
    setGlobals $PEER
    joinWithRetry $PEER $CHANNEL_NAME
    echo "===================== PEER$PEER joined on the channel \"$CHANNEL_NAME\" ===================== "
    sleep 2
    echo
}

installChaincode () {
	PEER=$1
	CHAINCODE_NAME=$2
	CHAINCODE_VERSION=$3

	setGlobals $PEER

	peer chaincode install -n $CHAINCODE_NAME -v 1.0 -p github.com/hyperledger/fabric/examples/$CHAINCODE_NAME >&fabric-v1.log
	res=$?
	cat fabric-v1.log
        verifyResult $res "$CHAINCODE_NAME Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== $CHAINCODE_NAME Chaincode is installed on remote peer PEER$PEER ===================== "
	echo
}

instantiateChaincode () {
	PEER=$1
	CHANNEL_NAME=$2
	CHAINCODE_NAME=$3
	setGlobals $PEER
    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o orderer.example.com:7050 -C $CHANNEL_NAME -n $CHAINCODE_NAME -v 1.0 -c '{"Args":[]}' -P "OR('Org1MSP.member')" >&fabric-v1.log
	else
		peer chaincode instantiate -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -v 1.0 -c '{"Args":[]}' >&fabric-v1.log
	fi
	res=$?
	cat fabric-v1.log
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

chaincodeQuery () {
  PEER=$1
  CHANNEL_NAME=$2
  CHAINCODE_NAME=$3
  KEY=$4
  QUERY="{\"Args\":[\"query\",\"$KEY\"]}"
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME -c $QUERY >&fabric-v1.log
     test $? -eq 0 && VALUE=$(cat fabric-v1.log | awk '/Query Result/ {print $NF}')  && let rc=0
     test $? -eq 1 && VALUE=$(cat fabric-v1.log | awk '/Error/ {print}')  && let rc=0
  done
  echo
  cat fabric-v1.log
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	echo
  fi
}

chaincodeInvoke () {
    PEER=$1
    CHANNEL_NAME=$2
    CHAINCODE_NAME=$3
    FUNCTION=$4

    ARGS=""
    for arg in ${@:5}
    do
      arg=`echo $arg | sed 's/"/\\\"/g'`
      ARGS+="\"$arg\","
    done

    ARGS=${ARGS:0:${#ARGS}-1}

    INVOKE="{\"Args\":[\"$FUNCTION\",$ARGS]}"

    echo "===================== Invoking on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
    setGlobals $PEER
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer.example.com:7050 -C $CHANNEL_NAME -n $CHAINCODE_NAME -c $INVOKE >&fabric-v1.log
	else
		peer chaincode invoke -o orderer.example.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c $INVOKE >&fabric-v1.log
	fi
	res=$?
	cat fabric-v1.log
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

demo() {
    echo "ISSUING A GEM"
    printf "\nInvoke to issue a gem on the PRIVATE CHANNEL (peer1)\n\n"
    read -n 1 -s -p "Press any key to start the interactive demo"
    chaincodeInvoke 1 private private-cc issueGem '{"id":"gem1","owner_id":"john","colour":"red","description":"shining!"}'

    printf "\n\nInvoke to certify a gem on the PRIVATE CHANNEL (peer0)\n\n"
    read -n 1 -s -p "Press any key to continue"
    chaincodeInvoke 0 private private-cc certifyGem gem1

    printf "\n\nQuery to retrieve information about the gem on the PRIVATE CHANNEL (peer1)\n\n"
    read -n 1 -s -p "Press any key to continue"
    chaincodeQuery 1 private private-cc gem1

    printf "\n\nOther peers not in the PRIVATE CHANNEL cannot see the information stored if they try to query it (peer2)\n\n"
    read -n 1 -s -p "Press any key to continue"
    chaincodeQuery 2 private private-cc gem1

    printf "\n\nInvoke to create a gem on the SHARING CHANNEL (peer0)\n\n"
    read -n 1 -s -p "Press any key to continue"
    chaincodeInvoke 0 sharing sharing-cc createGem '{"id":"gem1","colour":"red","description":"shining!","price":1500.34}'

    echo "TRADING A GEM"
    printf "\nInvoke to transfer the ownership of the gem from John (peer1), the seller, to Jane (peer2), the buyer, on the TRADING CHANNEL (peer1)\n\n"
    read -n 1 -s -p "Press any key to continue"
    chaincodeInvoke 1 trading trading-cc createTrade '{"id":"tx1","seller":"john","buyer":"jane","price":1500.34}'

    printf "\n\nQuery to retrieve the trade information on the TRADING CHANNEL (peer2)\n\n"
    read -n 1 -s -p "Press any key to continue"
    chaincodeQuery 2 trading trading-cc tx1

    printf "\n\nOther peers not in the TRADING CHANNEL cannot see the information stored if they try to query it (peer3)\n\n"
    read -n 1 -s -p "Press any key to continue"
    chaincodeQuery 3 trading trading-cc tx1

    printf "\n\nInvoke to update the ownership of a gem on the PRIVATE CHANNEL (peer0)\n\n"
    read -n 1 -s -p "Press any key to continue"
    chaincodeInvoke 0 private private-cc updateOwnership gem1 jane

    printf "\n\nInvoke to update the price of gem on the SHARING CHANNEL (peer0)\n\n"
    read -n 1 -s -p "Press any key to continue"
    chaincodeInvoke 0 sharing sharing-cc updateGemPrice gem1 2000.40

    printf "\n\nQuery to retrieve all the gems on the SHARING CHANNEL (peer3)\n\n"
    read -n 1 -s -p "Press any key to continue"
    chaincodeInvoke 3 sharing sharing-cc getAllGems available

    printf "\n\nThat's it! I hope you enjoyed this journey through the magical universe of Fabric channels :)\n\n"
}

readonly func="$1"
shift

if [ "$func" == "init" ]; then
     # Create channels, first argument is the channel name
    createChannel private
    createChannel trading
    createChannel sharing

    # Join all the peers to the channels, first argument is the peer, second argument is the channel name
    joinChannel 0 private
    joinChannel 1 private

    joinChannel 0 trading
    joinChannel 1 trading
    joinChannel 2 trading

    joinChannel 0 sharing
    joinChannel 1 sharing
    joinChannel 2 sharing
    joinChannel 3 sharing

    # Update anchor peers for all the channels
    updateAnchorPeers 0 private
    updateAnchorPeers 0 trading
    updateAnchorPeers 0 sharing

    # Install the chaincode on the peers, first argument is the peer, second argument is the chaincode name
    installChaincode 0 private-cc
    installChaincode 1 private-cc

    installChaincode 0 trading-cc
    installChaincode 1 trading-cc
    installChaincode 2 trading-cc

    installChaincode 0 sharing-cc
    installChaincode 1 sharing-cc
    installChaincode 2 sharing-cc
    installChaincode 3 sharing-cc

    # Instantiate chaincode, first argument is the peer, second argument is both the chaincode and channel name
    instantiateChaincode 0 private private-cc
    instantiateChaincode 0 trading trading-cc
    instantiateChaincode 0 sharing sharing-cc

    echo "===================== Network setup is successful ===================== "
elif [ "$func" == "demo" ]; then
    demo
elif [ "$func" == "setPeer" ]; then
    if [ -z $@ ]; then
        echo "Parameter missing"
        echo "$HELP"
        exit 1
    fi

    setGlobals $@
elif [ "$func" == "listFunctions" ]; then
    listFunctions
elif [ "$func" == "createChannel" ]; then
    if [ -z $@ ]; then
        echo "Parameter missing"
        echo "$HELP"
        exit 1
    fi

    createChannel $@
elif [ "$func" == "joinChannel" ]; then
    if [ -z $@ ]; then
        echo "Parameter missing"
        echo "$HELP"
        exit 1
    fi

    joinChannel $@
elif [ "$func" == "installChaincode" ]; then
    if [ -z $@ ]; then
        echo "Parameter missing"
        echo "$HELP"
        exit 1
    fi

    installChaincode $@
elif [ "$func" == "instantiateChaincode" ]; then
    if [ -z $@ ]; then
        echo "Parameter missing"
        echo "$HELP"
        exit 1
    fi

    instantiateChaincode $@
elif [ "$func" == "query" ]; then
    if [ -z $@ ]; then
        echo "Parameter missing"
        echo "$HELP"
        exit 1
    fi

    chaincodeQuery $@
elif [ "$func" == "invoke" ]; then
    if [ -z $@ ]; then
        echo "Parameter missing"
        echo "$HELP"
        exit 1
    fi
    
    chaincodeInvoke $@
else
    help
    exit 1
fi
