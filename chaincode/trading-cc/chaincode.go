package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	pb "github.com/hyperledger/fabric/protos/peer"
)

type SimpleChaincode struct {
}

type Trade struct {
	ID        string    `json:"id"`
	GemID     string    `json:"gem_id"`
	Seller    string    `json:"suller"`
	Buyer     string    `json:"buyer"`
	Price     float64   `json:"price"`
	Timestamp time.Time `json:"timestamp,omitempty"`
}

func (t *SimpleChaincode) Init(stub shim.ChaincodeStubInterface) pb.Response {
	fmt.Println("Trading chaincode initialized")
	return shim.Success(nil)
}

func (t *SimpleChaincode) Invoke(stub shim.ChaincodeStubInterface) pb.Response {
	fmt.Println("Trading chaincode invoke")
	function, args := stub.GetFunctionAndParameters()
	fmt.Println("Function " + function)
	fmt.Printf("Args: %v \n", args)

	if function == "createTrade" {
		return t.createTrade(stub, args)
	} else if function == "query" {
		return t.query(stub, args)
	}

	return shim.Error("Invalid invoke function name")
}

func (t *SimpleChaincode) createTrade(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	var trade Trade
	err := json.Unmarshal([]byte(args[0]), &trade)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}
	fmt.Println(trade)

	tradeAsBytes, err := json.Marshal(trade)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	timestamp, err := stub.GetTxTimestamp()
	trade.Timestamp = time.Unix(timestamp.GetSeconds(), 0)

	err = stub.PutState(trade.ID, tradeAsBytes)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	fmt.Println("TRADE REGISTERED")

	return shim.Success(nil)
}

func (t *SimpleChaincode) query(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	var ID string
	var err error

	if len(args) != 1 {
		return shim.Error("Query function requires one argument: ID")
	}

	ID = args[0]

	payload, err := stub.GetState(ID)
	if err != nil {
		return shim.Error("Failed to get state for: " + ID)
	}

	if payload == nil {
		return shim.Error("No results for: " + ID)
	}

	return shim.Success(payload)
}

func main() {
	err := shim.Start(new(SimpleChaincode))
	if err != nil {
		fmt.Printf("Error starting Simple chaincode: %s", err)
	}
}
