package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	pb "github.com/hyperledger/fabric/protos/peer"
)

type SimpleChaincode struct {
}

type Gem struct {
	ID          string    `json:"id"`
	Colour      string    `json:"colour"`
	Description string    `json:"description"`
	Price       float64   `json:"price"`
	CreatedAt   time.Time `json:"created_at,omitempty"`
	UpdatedAt   time.Time `json:"updated_at,omitempty"`
}

var GemIndexName = "gems"

func (t *SimpleChaincode) Init(stub shim.ChaincodeStubInterface) pb.Response {
	fmt.Println("Sharing chaincode initialized")

	var emptyIndex []string

	empty, err := json.Marshal(emptyIndex)
	if err != nil {
		return shim.Error("Error marshalling")
	}

	err = stub.PutState(GemIndexName, empty)
	if err != nil {
		return shim.Error("Error deleting index")
	}

	return shim.Success(nil)
}

func (t *SimpleChaincode) Invoke(stub shim.ChaincodeStubInterface) pb.Response {
	fmt.Println("Sharing chaincode invoke")
	function, args := stub.GetFunctionAndParameters()
	fmt.Println("Function " + function)
	fmt.Printf("Args: %v \n", args)

	if function == "createGem" {
		return t.createGem(stub, args)
	} else if function == "updateGemPrice" {
		return t.updateGemPrice(stub, args)
	} else if function == "getAllGems" {
		return t.getAllGems(stub, args)
	} else if function == "query" {
		return t.query(stub, args)
	}

	return shim.Error("Invalid invoke function name")
}

func (t *SimpleChaincode) createGem(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	var gem Gem
	err := json.Unmarshal([]byte(args[0]), &gem)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}
	fmt.Println(gem)

	timestamp, err := stub.GetTxTimestamp()
	fmt.Println(timestamp)
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

	index, err := GetIndex(stub, GemIndexName)
	if err != nil {
		return shim.Error(err.Error())
	}

	index = append(index, gem.ID)

	jsonAsBytes, err := json.Marshal(index)
	if err != nil {
		return shim.Error("Error marshalling index '" + GemIndexName + "': " + err.Error())
	}

	err = stub.PutState(GemIndexName, jsonAsBytes)
	if err != nil {
		return shim.Error("Error storing new " + GemIndexName + " into ledger")
	}

	fmt.Println("GEM CREATED")

	return shim.Success(nil)
}

func (t *SimpleChaincode) updateGemPrice(stub shim.ChaincodeStubInterface, args []string) pb.Response {
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

	gem.Price, err = strconv.ParseFloat(args[1], 64)
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

	fmt.Println("GEM PRICE UPDATED")

	return shim.Success(nil)
}

func (t *SimpleChaincode) getAllGems(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	gemIndex, err := GetIndex(stub, GemIndexName)
	if err != nil {
		return shim.Error(err.Error())
	}

	gems := []Gem{}

	for _, gemID := range gemIndex {
		gemAsBytes, err := stub.GetState(gemID)
		if err != nil {
			return shim.Error(err.Error())
		}

		gem := Gem{}

		err = json.Unmarshal(gemAsBytes, &gem)
		if err != nil {
			return shim.Error(err.Error())
		}

		gems = append(gems, gem)
	}

	gemAsBytes, err := json.Marshal(gems)
	if err != nil {
		fmt.Println(err)
		return shim.Error(err.Error())
	}

	return shim.Success(gemAsBytes)
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

func GetIndex(stub shim.ChaincodeStubInterface, indexName string) ([]string, error) {
	indexAsBytes, err := stub.GetState(indexName)
	if err != nil {
		return nil, errors.New("Failed to get " + indexName)
	}

	var index []string
	err = json.Unmarshal(indexAsBytes, &index)
	if err != nil {
		return nil, errors.New("Error unmarshalling index '" + indexName + "': " + err.Error())
	}

	return index, nil
}

func main() {
	err := shim.Start(new(SimpleChaincode))
	if err != nil {
		fmt.Printf("Error starting Simple chaincode: %s", err)
	}
}
