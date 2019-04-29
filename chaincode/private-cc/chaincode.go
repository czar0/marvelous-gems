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

func (t *SimpleChaincode) Init(stub shim.ChaincodeStubInterface) pb.Response {
	fmt.Println("Private chaincode initialized")
	return shim.Success(nil)
}

func (t *SimpleChaincode) Invoke(stub shim.ChaincodeStubInterface) pb.Response {
	fmt.Println("Private chaincode invoke")
	function, args := stub.GetFunctionAndParameters()
	fmt.Println("Function: " + function)
	fmt.Printf("Args: %v \n", args)

	if function == "issueGem" {
		return t.issueGem(stub, args)
	} else if function == "certifyGem" {
		return t.certifyGem(stub, args)
	} else if function == "updateOwnership" {
		return t.updateOwnership(stub, args)
	} else if function == "query" {
		return t.query(stub, args)
	}

	return shim.Error("Invalid invoke function name")
}

func (t *SimpleChaincode) issueGem(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	var gem Gem
	err := json.Unmarshal([]byte(args[0]), &gem)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}
	fmt.Println(gem)

	gem.Status = GEM_ISSUED
	timestamp, err := stub.GetTxTimestamp()
	gem.CreatedAt = time.Unix(timestamp.GetSeconds(), 0)

	gemAsBytes, err := json.Marshal(gem)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	err = stub.PutState(gem.ID, gemAsBytes)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	fmt.Println("GEM ISSUED")

	return shim.Success(nil)
}

func (t *SimpleChaincode) certifyGem(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	gemAsBytes, err := stub.GetState(args[0])
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	var gem Gem
	err = json.Unmarshal(gemAsBytes, &gem)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	gem.Status = GEM_CERTIFIED
	timestamp, err := stub.GetTxTimestamp()
	gem.UpdatedAt = time.Unix(timestamp.GetSeconds(), 0)

	gemAsBytes, err = json.Marshal(gem)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	err = stub.PutState(gem.ID, gemAsBytes)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	fmt.Println("GEM CERTIFIED")

	return shim.Success(nil)
}

func (t *SimpleChaincode) updateOwnership(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	gemAsBytes, err := stub.GetState(args[0])
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	var gem Gem
	err = json.Unmarshal(gemAsBytes, &gem)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	gem.PreviousOwners = append(gem.PreviousOwners, gem.OwnerID)
	gem.OwnerID = args[1]
	timestamp, err := stub.GetTxTimestamp()
	gem.UpdatedAt = time.Unix(timestamp.GetSeconds(), 0)

	gemAsBytes, err = json.Marshal(gem)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	err = stub.PutState(gem.ID, gemAsBytes)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	fmt.Println("OWNERSHIP UPDATED")

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
