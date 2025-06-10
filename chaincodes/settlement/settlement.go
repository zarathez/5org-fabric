// settlement.go - Updated to include securities initialization for Broker2
package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SettlementContract provides functions for settling trades
type SettlementContract struct {
	contractapi.Contract
}

// Trade represents a matched trade between buy and sell orders
type Trade struct {
	TradeID      string  `json:"tradeID"`
	BuyOrderID   string  `json:"buyOrderID"`
	SellOrderID  string  `json:"sellOrderID"`
	BuyBrokerID  string  `json:"buyBrokerID"`
	SellBrokerID string  `json:"sellBrokerID"`
	SecurityID   string  `json:"securityID"`
	Quantity     int     `json:"quantity"`
	Price        float64 `json:"price"`
	Status       string  `json:"status"` // pending, approved, rejected, settled
	MatchTime    string  `json:"matchTime"`
}

// SettlementInstruction represents instructions for settlement
type SettlementInstruction struct {
	InstructionID  string  `json:"instructionID"`
	TradeID        string  `json:"tradeID"`
	BuyBrokerID    string  `json:"buyBrokerID"`
	SellBrokerID   string  `json:"sellBrokerID"`
	SecurityID     string  `json:"securityID"`
	Quantity       int     `json:"quantity"`
	Price          float64 `json:"price"`
	TotalAmount    float64 `json:"totalAmount"`
	Status         string  `json:"status"` // pending, validated, completed, failed
	CreatedAt      string  `json:"createdAt"`
	SettlementDate string  `json:"settlementDate"`
	CompletedAt    string  `json:"completedAt"`
}

// BrokerAccount represents a broker's cash account
type BrokerAccount struct {
	BrokerID        string  `json:"brokerID"`
	Balance         float64 `json:"balance"`
	ReservedBalance float64 `json:"reservedBalance"`
	LastUpdated     string  `json:"lastUpdated"`
}

// SecuritiesAccount represents a broker's securities account
type SecuritiesAccount struct {
	AccountID   string `json:"accountID"`
	BrokerID    string `json:"brokerID"`
	SecurityID  string `json:"securityID"`
	Quantity    int    `json:"quantity"`
	ReservedQty int    `json:"reservedQty"`
	LastUpdated string `json:"lastUpdated"`
}

// GuaranteeDeposit represents a broker's guarantee deposit with the exchange
type GuaranteeDeposit struct {
	BrokerID    string  `json:"brokerID"`
	Amount      float64 `json:"amount"`
	LastUpdated string  `json:"lastUpdated"`
}

// GuaranteeFund represents the exchange's central guarantee fund
type GuaranteeFund struct {
	TotalAmount float64 `json:"totalAmount"`
	LastUpdated string  `json:"lastUpdated"`
}

// Transaction represents a cash or security transaction
type Transaction struct {
	TransactionID string  `json:"transactionID"`
	Type          string  `json:"type"`       // cash, security
	FromID        string  `json:"fromID"`     // broker ID
	ToID          string  `json:"toID"`       // broker ID
	SecurityID    string  `json:"securityID"` // for security transactions
	Amount        float64 `json:"amount"`     // cash amount or security quantity
	InstructionID string  `json:"instructionID"`
	Status        string  `json:"status"` // completed, failed
	Timestamp     string  `json:"timestamp"`
}

// Helper function to get deterministic timestamp
func (s *SettlementContract) getTransactionTimestamp(ctx contractapi.TransactionContextInterface) string {
	timestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		// Fallback to current time if timestamp not available
		return time.Now().Format(time.RFC3339)
	}
	return time.Unix(timestamp.Seconds, int64(timestamp.Nanos)).Format(time.RFC3339)
}

// Helper function to get deterministic transaction ID
func (s *SettlementContract) getTransactionID(ctx contractapi.TransactionContextInterface) string {
	return ctx.GetStub().GetTxID()
}

// InitializeBrokerSecurities creates initial securities holdings for brokers
func (s *SettlementContract) InitializeBrokerSecurities(ctx contractapi.TransactionContextInterface) error {
	currentTime := s.getTransactionTimestamp(ctx)
	txID := s.getTransactionID(ctx)

	// Define initial securities for Broker2
	broker2Securities := []struct {
		SecurityID string
		Quantity   int
	}{
		{"SEC000", 1500}, // 1500 shares of Itissalat Al-Maghrib (IAM)
		{"SEC002", 800},  // 800 shares of Banque Centrale Populaire (BCP)
		{"SEC003", 600},  // 600 shares of Attijariwafa Bank (ATW)
		{"SEC004", 1000}, // 1000 shares of Cosumar S.A. (CSMR)
	}

	// Create securities accounts for Broker2
	for i, security := range broker2Securities {
		accountID := fmt.Sprintf("securitiesAccount-broker2-%s", security.SecurityID)

		// Check if account already exists
		existingAccountJSON, err := ctx.GetStub().GetState(accountID)
		if err != nil {
			return fmt.Errorf("failed to read existing securities account: %v", err)
		}

		if existingAccountJSON != nil {
			// Account exists, update quantity
			var existingAccount SecuritiesAccount
			err = json.Unmarshal(existingAccountJSON, &existingAccount)
			if err != nil {
				return fmt.Errorf("failed to unmarshal existing securities account: %v", err)
			}

			existingAccount.Quantity += security.Quantity
			existingAccount.LastUpdated = currentTime

			updatedAccountJSON, err := json.Marshal(existingAccount)
			if err != nil {
				return fmt.Errorf("failed to marshal updated securities account: %v", err)
			}

			err = ctx.GetStub().PutState(accountID, updatedAccountJSON)
			if err != nil {
				return fmt.Errorf("failed to update securities account in ledger: %v", err)
			}
		} else {
			// Create new account
			account := SecuritiesAccount{
				AccountID:   accountID,
				BrokerID:    "broker2",
				SecurityID:  security.SecurityID,
				Quantity:    security.Quantity,
				ReservedQty: 0,
				LastUpdated: currentTime,
			}

			accountJSON, err := json.Marshal(account)
			if err != nil {
				return fmt.Errorf("failed to marshal securities account: %v", err)
			}

			err = ctx.GetStub().PutState(accountID, accountJSON)
			if err != nil {
				return fmt.Errorf("failed to put securities account in ledger: %v", err)
			}
		}

		// Record the securities deposit transaction with deterministic ID
		transactionID := fmt.Sprintf("transaction-init-securities-broker2-%s-%s-%d", security.SecurityID, txID, i)
		transaction := Transaction{
			TransactionID: transactionID,
			Type:          "security_deposit",
			FromID:        "system",
			ToID:          "broker2",
			SecurityID:    security.SecurityID,
			Amount:        float64(security.Quantity),
			InstructionID: "",
			Status:        "completed",
			Timestamp:     currentTime,
		}

		transactionJSON, err := json.Marshal(transaction)
		if err != nil {
			return fmt.Errorf("failed to marshal securities transaction: %v", err)
		}

		err = ctx.GetStub().PutState(transactionID, transactionJSON)
		if err != nil {
			return fmt.Errorf("failed to save securities transaction in ledger: %v", err)
		}
	}

	// Initialize cash for brokers
	brokerInitialBalances := []struct {
		BrokerID string
		Balance  float64
	}{
		{"broker1", 1500000.0}, // 1.5 Million MAD for Broker1
		{"broker2", 500000.0},  // 500,000 MAD for Broker2
	}

	for j, broker := range brokerInitialBalances {
		accountID := fmt.Sprintf("brokerAccount-%s", broker.BrokerID)

		// Check if account already exists
		existingAccountJSON, err := ctx.GetStub().GetState(accountID)
		if err != nil {
			return fmt.Errorf("failed to read existing broker account: %v", err)
		}

		if existingAccountJSON == nil {
			// Create new broker account
			account := BrokerAccount{
				BrokerID:        broker.BrokerID,
				Balance:         broker.Balance,
				ReservedBalance: 0,
				LastUpdated:     currentTime,
			}

			accountJSON, err := json.Marshal(account)
			if err != nil {
				return fmt.Errorf("failed to marshal broker account: %v", err)
			}

			err = ctx.GetStub().PutState(accountID, accountJSON)
			if err != nil {
				return fmt.Errorf("failed to put broker account in ledger: %v", err)
			}

			// Record the cash deposit transaction with deterministic ID
			transactionID := fmt.Sprintf("transaction-init-cash-%s-%s-%d", broker.BrokerID, txID, j)
			transaction := Transaction{
				TransactionID: transactionID,
				Type:          "deposit",
				FromID:        "system",
				ToID:          broker.BrokerID,
				SecurityID:    "",
				Amount:        broker.Balance,
				InstructionID: "",
				Status:        "completed",
				Timestamp:     currentTime,
			}

			transactionJSON, err := json.Marshal(transaction)
			if err != nil {
				return fmt.Errorf("failed to marshal cash transaction: %v", err)
			}

			err = ctx.GetStub().PutState(transactionID, transactionJSON)
			if err != nil {
				return fmt.Errorf("failed to save cash transaction in ledger: %v", err)
			}
		}
	}

	return nil
}

// InitLedger initializes the ledger with sample data including broker securities
func (s *SettlementContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	currentTime := s.getTransactionTimestamp(ctx)

	// Initialize the guarantee fund
	guaranteeFund := GuaranteeFund{
		TotalAmount: 0,
		LastUpdated: currentTime,
	}

	guaranteeFundJSON, err := json.Marshal(guaranteeFund)
	if err != nil {
		return fmt.Errorf("failed to marshal guarantee fund: %v", err)
	}

	err = ctx.GetStub().PutState("guaranteeFund", guaranteeFundJSON)
	if err != nil {
		return fmt.Errorf("failed to put guarantee fund in ledger: %v", err)
	}

	// Initialize broker securities and accounts
	err = s.InitializeBrokerSecurities(ctx)
	if err != nil {
		return fmt.Errorf("failed to initialize broker securities: %v", err)
	}

	return nil
}

// CreateBrokerAccount creates a new broker account
func (s *SettlementContract) CreateBrokerAccount(ctx contractapi.TransactionContextInterface, brokerID string, initialBalance float64) error {
	// Check if the broker account already exists
	brokerAccountJSON, err := ctx.GetStub().GetState("brokerAccount-" + brokerID)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if brokerAccountJSON != nil {
		return fmt.Errorf("broker account %s already exists", brokerID)
	}

	// Create broker account
	currentTime := time.Now().Format(time.RFC3339)
	brokerAccount := BrokerAccount{
		BrokerID:        brokerID,
		Balance:         initialBalance,
		ReservedBalance: 0,
		LastUpdated:     currentTime,
	}

	// Store broker account in ledger
	brokerAccountJSON, err = json.Marshal(brokerAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal broker account: %v", err)
	}

	err = ctx.GetStub().PutState("brokerAccount-"+brokerID, brokerAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to put broker account in ledger: %v", err)
	}

	return nil
}

// GetBrokerAccount retrieves a broker account by ID
func (s *SettlementContract) GetBrokerAccount(ctx contractapi.TransactionContextInterface, brokerID string) (*BrokerAccount, error) {
	brokerAccountJSON, err := ctx.GetStub().GetState("brokerAccount-" + brokerID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if brokerAccountJSON == nil {
		return nil, fmt.Errorf("broker account %s does not exist", brokerID)
	}

	var brokerAccount BrokerAccount
	err = json.Unmarshal(brokerAccountJSON, &brokerAccount)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal broker account: %v", err)
	}

	return &brokerAccount, nil
}

// CreateSecuritiesAccount creates a new securities account for a broker and security
func (s *SettlementContract) CreateSecuritiesAccount(ctx contractapi.TransactionContextInterface, brokerID, securityID string, initialQuantity int) error {
	// Create account ID
	accountID := "securitiesAccount-" + brokerID + "-" + securityID

	// Check if the account already exists
	accountJSON, err := ctx.GetStub().GetState(accountID)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if accountJSON != nil {
		return fmt.Errorf("securities account for broker %s and security %s already exists", brokerID, securityID)
	}

	// Create securities account
	currentTime := time.Now().Format(time.RFC3339)
	account := SecuritiesAccount{
		AccountID:   accountID,
		BrokerID:    brokerID,
		SecurityID:  securityID,
		Quantity:    initialQuantity,
		ReservedQty: 0,
		LastUpdated: currentTime,
	}

	// Store account in ledger
	accountJSON, err = json.Marshal(account)
	if err != nil {
		return fmt.Errorf("failed to marshal securities account: %v", err)
	}

	err = ctx.GetStub().PutState(accountID, accountJSON)
	if err != nil {
		return fmt.Errorf("failed to put securities account in ledger: %v", err)
	}

	return nil
}

// GetSecuritiesAccount retrieves a securities account by broker ID and security ID
func (s *SettlementContract) GetSecuritiesAccount(ctx contractapi.TransactionContextInterface, brokerID, securityID string) (*SecuritiesAccount, error) {
	accountID := "securitiesAccount-" + brokerID + "-" + securityID
	accountJSON, err := ctx.GetStub().GetState(accountID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if accountJSON == nil {
		return nil, fmt.Errorf("securities account for broker %s and security %s does not exist", brokerID, securityID)
	}

	var account SecuritiesAccount
	err = json.Unmarshal(accountJSON, &account)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal securities account: %v", err)
	}

	return &account, nil
}

// CreateGuaranteeDeposit creates a new guarantee deposit for a broker
func (s *SettlementContract) CreateGuaranteeDeposit(ctx contractapi.TransactionContextInterface, brokerID string, initialAmount float64) error {
	// Check if the deposit already exists
	depositJSON, err := ctx.GetStub().GetState("guaranteeDeposit-" + brokerID)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if depositJSON != nil {
		return fmt.Errorf("guarantee deposit for broker %s already exists", brokerID)
	}

	// Create guarantee deposit
	currentTime := time.Now().Format(time.RFC3339)
	deposit := GuaranteeDeposit{
		BrokerID:    brokerID,
		Amount:      initialAmount,
		LastUpdated: currentTime,
	}

	// Store deposit in ledger
	depositJSON, err = json.Marshal(deposit)
	if err != nil {
		return fmt.Errorf("failed to marshal guarantee deposit: %v", err)
	}

	err = ctx.GetStub().PutState("guaranteeDeposit-"+brokerID, depositJSON)
	if err != nil {
		return fmt.Errorf("failed to put guarantee deposit in ledger: %v", err)
	}

	// Update guarantee fund
	guaranteeFund, err := s.GetGuaranteeFund(ctx)
	if err != nil {
		return fmt.Errorf("failed to get guarantee fund: %v", err)
	}

	guaranteeFund.TotalAmount += initialAmount
	guaranteeFund.LastUpdated = currentTime

	guaranteeFundJSON, err := json.Marshal(guaranteeFund)
	if err != nil {
		return fmt.Errorf("failed to marshal guarantee fund: %v", err)
	}

	err = ctx.GetStub().PutState("guaranteeFund", guaranteeFundJSON)
	if err != nil {
		return fmt.Errorf("failed to update guarantee fund in ledger: %v", err)
	}

	return nil
}

// GetGuaranteeDeposit retrieves a guarantee deposit by broker ID
func (s *SettlementContract) GetGuaranteeDeposit(ctx contractapi.TransactionContextInterface, brokerID string) (*GuaranteeDeposit, error) {
	depositJSON, err := ctx.GetStub().GetState("guaranteeDeposit-" + brokerID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if depositJSON == nil {
		return nil, fmt.Errorf("guarantee deposit for broker %s does not exist", brokerID)
	}

	var deposit GuaranteeDeposit
	err = json.Unmarshal(depositJSON, &deposit)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal guarantee deposit: %v", err)
	}

	return &deposit, nil
}

// GetGuaranteeFund retrieves the guarantee fund
func (s *SettlementContract) GetGuaranteeFund(ctx contractapi.TransactionContextInterface) (*GuaranteeFund, error) {
	guaranteeFundJSON, err := ctx.GetStub().GetState("guaranteeFund")
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if guaranteeFundJSON == nil {
		return nil, fmt.Errorf("guarantee fund does not exist")
	}

	var guaranteeFund GuaranteeFund
	err = json.Unmarshal(guaranteeFundJSON, &guaranteeFund)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal guarantee fund: %v", err)
	}

	return &guaranteeFund, nil
}

// DepositGuarantee allows a broker to deposit additional funds to their guarantee deposit
func (s *SettlementContract) DepositGuarantee(ctx contractapi.TransactionContextInterface, brokerID string, amount float64) error {
	if amount <= 0 {
		return fmt.Errorf("deposit amount must be positive")
	}

	// Get broker account
	brokerAccount, err := s.GetBrokerAccount(ctx, brokerID)
	if err != nil {
		return fmt.Errorf("failed to get broker account: %v", err)
	}

	// Check if broker has sufficient funds
	if brokerAccount.Balance < amount {
		return fmt.Errorf("insufficient funds in broker account")
	}

	// Get guarantee deposit
	deposit, err := s.GetGuaranteeDeposit(ctx, brokerID)
	if err != nil {
		return fmt.Errorf("failed to get guarantee deposit: %v", err)
	}

	// Get guarantee fund
	guaranteeFund, err := s.GetGuaranteeFund(ctx)
	if err != nil {
		return fmt.Errorf("failed to get guarantee fund: %v", err)
	}

	// Update broker account
	brokerAccount.Balance -= amount
	brokerAccount.LastUpdated = time.Now().Format(time.RFC3339)

	// Update guarantee deposit
	deposit.Amount += amount
	deposit.LastUpdated = brokerAccount.LastUpdated

	// Update guarantee fund
	guaranteeFund.TotalAmount += amount
	guaranteeFund.LastUpdated = brokerAccount.LastUpdated

	// Store updated broker account
	brokerAccountJSON, err := json.Marshal(brokerAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal broker account: %v", err)
	}

	err = ctx.GetStub().PutState("brokerAccount-"+brokerID, brokerAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to update broker account in ledger: %v", err)
	}

	// Store updated guarantee deposit
	depositJSON, err := json.Marshal(deposit)
	if err != nil {
		return fmt.Errorf("failed to marshal guarantee deposit: %v", err)
	}

	err = ctx.GetStub().PutState("guaranteeDeposit-"+brokerID, depositJSON)
	if err != nil {
		return fmt.Errorf("failed to update guarantee deposit in ledger: %v", err)
	}

	// Store updated guarantee fund
	guaranteeFundJSON, err := json.Marshal(guaranteeFund)
	if err != nil {
		return fmt.Errorf("failed to marshal guarantee fund: %v", err)
	}

	err = ctx.GetStub().PutState("guaranteeFund", guaranteeFundJSON)
	if err != nil {
		return fmt.Errorf("failed to update guarantee fund in ledger: %v", err)
	}

	return nil
}

// CreateSettlementInstruction creates a new settlement instruction for a trade
func (s *SettlementContract) CreateSettlementInstruction(ctx contractapi.TransactionContextInterface, tradeID string) error {
	// Check if the instruction already exists
	instructionID := "instruction-" + tradeID
	instructionJSON, err := ctx.GetStub().GetState(instructionID)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if instructionJSON != nil {
		return fmt.Errorf("settlement instruction for trade %s already exists", tradeID)
	}

	// Get the trade
	tradeJSON, err := ctx.GetStub().GetState(tradeID)
	if err != nil {
		return fmt.Errorf("failed to read trade from world state: %v", err)
	}
	if tradeJSON == nil {
		return fmt.Errorf("trade %s does not exist", tradeID)
	}

	var trade Trade
	err = json.Unmarshal(tradeJSON, &trade)
	if err != nil {
		return fmt.Errorf("failed to unmarshal trade: %v", err)
	}

	// Check if trade is approved
	if trade.Status != "approved" {
		return fmt.Errorf("only approved trades can be settled, current status: %s", trade.Status)
	}

	// Calculate total amount
	totalAmount := float64(trade.Quantity) * trade.Price

	// Create settlement instruction
	currentTime := time.Now().Format(time.RFC3339)

	// Set settlement date to T+3 (in a real system, this would account for business days)
	settlementDate := time.Now().AddDate(0, 0, 3).Format(time.RFC3339)

	instruction := SettlementInstruction{
		InstructionID:  instructionID,
		TradeID:        tradeID,
		BuyBrokerID:    trade.BuyBrokerID,
		SellBrokerID:   trade.SellBrokerID,
		SecurityID:     trade.SecurityID,
		Quantity:       trade.Quantity,
		Price:          trade.Price,
		TotalAmount:    totalAmount,
		Status:         "pending",
		CreatedAt:      currentTime,
		SettlementDate: settlementDate,
		CompletedAt:    "",
	}

	// Store the instruction in ledger
	instructionJSON, err = json.Marshal(instruction)
	if err != nil {
		return fmt.Errorf("failed to marshal settlement instruction: %v", err)
	}

	err = ctx.GetStub().PutState(instructionID, instructionJSON)
	if err != nil {
		return fmt.Errorf("failed to put settlement instruction in ledger: %v", err)
	}

	// Reserve funds for the buyer
	buyerAccount, err := s.GetBrokerAccount(ctx, trade.BuyBrokerID)
	if err != nil {
		// If account doesn't exist, create it
		err = s.CreateBrokerAccount(ctx, trade.BuyBrokerID, 0)
		if err != nil {
			return fmt.Errorf("failed to create buyer broker account: %v", err)
		}
		buyerAccount, err = s.GetBrokerAccount(ctx, trade.BuyBrokerID)
		if err != nil {
			return fmt.Errorf("failed to get buyer broker account: %v", err)
		}
	}

	// Check if buyer has sufficient funds
	if buyerAccount.Balance < totalAmount {
		return fmt.Errorf("buyer broker does not have sufficient funds for settlement")
	}

	// Reserve the funds
	buyerAccount.ReservedBalance += totalAmount
	buyerAccount.LastUpdated = currentTime

	buyerAccountJSON, err := json.Marshal(buyerAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal buyer broker account: %v", err)
	}

	err = ctx.GetStub().PutState("brokerAccount-"+trade.BuyBrokerID, buyerAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to update buyer broker account: %v", err)
	}

	// Reserve securities for the seller
	sellerSecuritiesAccount, err := s.GetSecuritiesAccount(ctx, trade.SellBrokerID, trade.SecurityID)
	if err != nil {
		return fmt.Errorf("seller broker does not have securities account for this security: %v", err)
	}

	// Check if seller has sufficient securities
	if sellerSecuritiesAccount.Quantity < trade.Quantity {
		return fmt.Errorf("seller broker does not have sufficient securities for settlement")
	}

	// Reserve the securities
	sellerSecuritiesAccount.ReservedQty += trade.Quantity
	sellerSecuritiesAccount.LastUpdated = currentTime

	sellerSecuritiesAccountJSON, err := json.Marshal(sellerSecuritiesAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal seller securities account: %v", err)
	}

	err = ctx.GetStub().PutState(sellerSecuritiesAccount.AccountID, sellerSecuritiesAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to update seller securities account: %v", err)
	}

	// Emit an event for the settlement instruction creation
	err = ctx.GetStub().SetEvent("SettlementInstructionCreated", instructionJSON)
	if err != nil {
		return fmt.Errorf("failed to set SettlementInstructionCreated event: %v", err)
	}

	return nil
}

// GetSettlementInstruction retrieves a settlement instruction by ID
func (s *SettlementContract) GetSettlementInstruction(ctx contractapi.TransactionContextInterface, instructionID string) (*SettlementInstruction, error) {
	instructionJSON, err := ctx.GetStub().GetState(instructionID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if instructionJSON == nil {
		return nil, fmt.Errorf("settlement instruction %s does not exist", instructionID)
	}

	var instruction SettlementInstruction
	err = json.Unmarshal(instructionJSON, &instruction)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal settlement instruction: %v", err)
	}

	return &instruction, nil
}

// ValidateSettlementInstruction allows brokers to validate a settlement instruction
func (s *SettlementContract) ValidateSettlementInstruction(ctx contractapi.TransactionContextInterface, instructionID string) error {
	instruction, err := s.GetSettlementInstruction(ctx, instructionID)
	if err != nil {
		return err
	}

	// Check if instruction is pending
	if instruction.Status != "pending" {
		return fmt.Errorf("only pending instructions can be validated, current status: %s", instruction.Status)
	}

	// Update instruction status
	instruction.Status = "validated"

	// Store the updated instruction
	instructionJSON, err := json.Marshal(instruction)
	if err != nil {
		return fmt.Errorf("failed to marshal settlement instruction: %v", err)
	}

	err = ctx.GetStub().PutState(instructionID, instructionJSON)
	if err != nil {
		return fmt.Errorf("failed to update settlement instruction in ledger: %v", err)
	}

	// Emit an event for the validation
	err = ctx.GetStub().SetEvent("SettlementInstructionValidated", instructionJSON)
	if err != nil {
		return fmt.Errorf("failed to set SettlementInstructionValidated event: %v", err)
	}

	return nil
}

// GetTrade retrieves a trade by ID (helper function)
func (s *SettlementContract) GetTrade(ctx contractapi.TransactionContextInterface, tradeID string) (*Trade, error) {
	tradeJSON, err := ctx.GetStub().GetState(tradeID)
	if err != nil {
		return nil, fmt.Errorf("failed to read trade from world state: %v", err)
	}
	if tradeJSON == nil {
		return nil, fmt.Errorf("trade %s does not exist", tradeID)
	}

	var trade Trade
	err = json.Unmarshal(tradeJSON, &trade)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal trade: %v", err)
	}

	return &trade, nil
}

// ExecuteSettlement executes the settlement for a given instruction
func (s *SettlementContract) ExecuteSettlement(ctx contractapi.TransactionContextInterface, instructionID string) error {
	// Get the instruction
	instruction, err := s.GetSettlementInstruction(ctx, instructionID)
	if err != nil {
		return err
	}

	// Check if instruction is validated
	if instruction.Status != "validated" && instruction.Status != "pending" {
		return fmt.Errorf("only validated or pending instructions can be executed, current status: %s", instruction.Status)
	}

	currentTime := time.Now().Format(time.RFC3339)

	// 1. Transfer funds from buyer to seller
	buyerAccount, err := s.GetBrokerAccount(ctx, instruction.BuyBrokerID)
	if err != nil {
		return fmt.Errorf("failed to get buyer broker account: %v", err)
	}

	// Verify buyer has sufficient funds
	if buyerAccount.Balance < instruction.TotalAmount {
		return s.ProcessFail(ctx, instructionID, "buyer_insufficient_funds")
	}

	sellerAccount, err := s.GetBrokerAccount(ctx, instruction.SellBrokerID)
	if err != nil {
		// If seller account doesn't exist, create it
		err = s.CreateBrokerAccount(ctx, instruction.SellBrokerID, 0)
		if err != nil {
			return fmt.Errorf("failed to create seller broker account: %v", err)
		}
		sellerAccount, err = s.GetBrokerAccount(ctx, instruction.SellBrokerID)
		if err != nil {
			return fmt.Errorf("failed to get seller broker account: %v", err)
		}
	}

	// 2. Transfer securities from seller to buyer
	sellerSecuritiesAccount, err := s.GetSecuritiesAccount(ctx, instruction.SellBrokerID, instruction.SecurityID)
	if err != nil {
		return fmt.Errorf("failed to get seller securities account: %v", err)
	}

	// Verify seller has sufficient securities
	if sellerSecuritiesAccount.Quantity < instruction.Quantity {
		return s.ProcessFail(ctx, instructionID, "seller_insufficient_securities")
	}

	buyerSecuritiesAccount, err := s.GetSecuritiesAccount(ctx, instruction.BuyBrokerID, instruction.SecurityID)
	if err != nil {
		// If buyer securities account doesn't exist, create it
		err = s.CreateSecuritiesAccount(ctx, instruction.BuyBrokerID, instruction.SecurityID, 0)
		if err != nil {
			return fmt.Errorf("failed to create buyer securities account: %v", err)
		}
		buyerSecuritiesAccount, err = s.GetSecuritiesAccount(ctx, instruction.BuyBrokerID, instruction.SecurityID)
		if err != nil {
			return fmt.Errorf("failed to get buyer securities account: %v", err)
		}
	}

	// Update accounts
	// 1. Update cash accounts
	buyerAccount.Balance -= instruction.TotalAmount
	buyerAccount.ReservedBalance -= instruction.TotalAmount
	buyerAccount.LastUpdated = currentTime

	sellerAccount.Balance += instruction.TotalAmount
	sellerAccount.LastUpdated = currentTime

	// 2. Update securities accounts
	sellerSecuritiesAccount.Quantity -= instruction.Quantity
	sellerSecuritiesAccount.ReservedQty -= instruction.Quantity
	sellerSecuritiesAccount.LastUpdated = currentTime

	buyerSecuritiesAccount.Quantity += instruction.Quantity
	buyerSecuritiesAccount.LastUpdated = currentTime

	// 3. Create transactions for funds and securities
	cashTransactionID := "transaction-cash-" + instruction.InstructionID
	cashTransaction := Transaction{
		TransactionID: cashTransactionID,
		Type:          "cash",
		FromID:        instruction.BuyBrokerID,
		ToID:          instruction.SellBrokerID,
		SecurityID:    "",
		Amount:        instruction.TotalAmount,
		InstructionID: instruction.InstructionID,
		Status:        "completed",
		Timestamp:     currentTime,
	}

	securitiesTransactionID := "transaction-securities-" + instruction.InstructionID
	securitiesTransaction := Transaction{
		TransactionID: securitiesTransactionID,
		Type:          "security",
		FromID:        instruction.SellBrokerID,
		ToID:          instruction.BuyBrokerID,
		SecurityID:    instruction.SecurityID,
		Amount:        float64(instruction.Quantity),
		InstructionID: instruction.InstructionID,
		Status:        "completed",
		Timestamp:     currentTime,
	}

	// 4. Update instruction status
	instruction.Status = "completed"
	instruction.CompletedAt = currentTime

	// 5. Update trade status
	trade, err := s.GetTrade(ctx, instruction.TradeID)
	if err != nil {
		return fmt.Errorf("failed to get trade: %v", err)
	}

	trade.Status = "settled"

	// 6. Save all changes to ledger
	// Save broker accounts
	buyerAccountJSON, err := json.Marshal(buyerAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal buyer broker account: %v", err)
	}

	err = ctx.GetStub().PutState("brokerAccount-"+instruction.BuyBrokerID, buyerAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to update buyer broker account in ledger: %v", err)
	}

	sellerAccountJSON, err := json.Marshal(sellerAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal seller broker account: %v", err)
	}

	err = ctx.GetStub().PutState("brokerAccount-"+instruction.SellBrokerID, sellerAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to update seller broker account in ledger: %v", err)
	}

	// Save securities accounts
	buyerSecuritiesAccountJSON, err := json.Marshal(buyerSecuritiesAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal buyer securities account: %v", err)
	}

	err = ctx.GetStub().PutState(buyerSecuritiesAccount.AccountID, buyerSecuritiesAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to update buyer securities account in ledger: %v", err)
	}

	sellerSecuritiesAccountJSON, err := json.Marshal(sellerSecuritiesAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal seller securities account: %v", err)
	}

	err = ctx.GetStub().PutState(sellerSecuritiesAccount.AccountID, sellerSecuritiesAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to update seller securities account in ledger: %v", err)
	}

	// Save transactions
	cashTransactionJSON, err := json.Marshal(cashTransaction)
	if err != nil {
		return fmt.Errorf("failed to marshal cash transaction: %v", err)
	}

	err = ctx.GetStub().PutState(cashTransactionID, cashTransactionJSON)
	if err != nil {
		return fmt.Errorf("failed to save cash transaction in ledger: %v", err)
	}

	securitiesTransactionJSON, err := json.Marshal(securitiesTransaction)
	if err != nil {
		return fmt.Errorf("failed to marshal securities transaction: %v", err)
	}

	err = ctx.GetStub().PutState(securitiesTransactionID, securitiesTransactionJSON)
	if err != nil {
		return fmt.Errorf("failed to save securities transaction in ledger: %v", err)
	}

	// Save instruction
	instructionJSON, err := json.Marshal(instruction)
	if err != nil {
		return fmt.Errorf("failed to marshal settlement instruction: %v", err)
	}

	err = ctx.GetStub().PutState(instructionID, instructionJSON)
	if err != nil {
		return fmt.Errorf("failed to update settlement instruction in ledger: %v", err)
	}

	// Save trade
	tradeJSON, err := json.Marshal(trade)
	if err != nil {
		return fmt.Errorf("failed to marshal trade: %v", err)
	}

	err = ctx.GetStub().PutState(instruction.TradeID, tradeJSON)
	if err != nil {
		return fmt.Errorf("failed to update trade in ledger: %v", err)
	}

	// Emit an event for the settlement execution
	err = ctx.GetStub().SetEvent("SettlementExecuted", instructionJSON)
	if err != nil {
		return fmt.Errorf("failed to set SettlementExecuted event: %v", err)
	}

	return nil
}

// ProcessFail handles settlement failures
func (s *SettlementContract) ProcessFail(ctx contractapi.TransactionContextInterface, instructionID string, failureReason string) error {
	// Get the instruction
	instruction, err := s.GetSettlementInstruction(ctx, instructionID)
	if err != nil {
		return err
	}

	currentTime := time.Now().Format(time.RFC3339)

	// Update instruction status
	instruction.Status = "failed"
	instruction.CompletedAt = currentTime

	// Store the instruction
	instructionJSON, err := json.Marshal(instruction)
	if err != nil {
		return fmt.Errorf("failed to marshal settlement instruction: %v", err)
	}

	err = ctx.GetStub().PutState(instructionID, instructionJSON)
	if err != nil {
		return fmt.Errorf("failed to update settlement instruction in ledger: %v", err)
	}

	// Get the guarantee deposit of the defaulting broker
	var defaultingBrokerID string
	if failureReason == "buyer_insufficient_funds" {
		defaultingBrokerID = instruction.BuyBrokerID
	} else if failureReason == "seller_insufficient_securities" {
		defaultingBrokerID = instruction.SellBrokerID
	} else {
		return fmt.Errorf("unknown failure reason: %s", failureReason)
	}

	deposit, err := s.GetGuaranteeDeposit(ctx, defaultingBrokerID)
	if err != nil {
		return fmt.Errorf("failed to get guarantee deposit: %v", err)
	}

	// Get the guarantee fund
	guaranteeFund, err := s.GetGuaranteeFund(ctx)
	if err != nil {
		return fmt.Errorf("failed to get guarantee fund: %v", err)
	}

	// Determine how much to use from deposit and fund
	var amountNeeded float64
	if failureReason == "buyer_insufficient_funds" {
		amountNeeded = instruction.TotalAmount
	} else {
		// For securities failure, convert to cash value
		amountNeeded = float64(instruction.Quantity) * instruction.Price
	}

	// Use deposit first, then fund if needed
	var amountFromDeposit float64
	var amountFromFund float64

	if deposit.Amount >= amountNeeded {
		amountFromDeposit = amountNeeded
		amountFromFund = 0
	} else {
		amountFromDeposit = deposit.Amount
		amountFromFund = amountNeeded - amountFromDeposit
	}

	// Update deposit
	deposit.Amount -= amountFromDeposit
	deposit.LastUpdated = currentTime

	// Update fund
	guaranteeFund.TotalAmount -= amountFromFund
	guaranteeFund.LastUpdated = currentTime

	// Store updated deposit
	depositJSON, err := json.Marshal(deposit)
	if err != nil {
		return fmt.Errorf("failed to marshal guarantee deposit: %v", err)
	}

	err = ctx.GetStub().PutState("guaranteeDeposit-"+defaultingBrokerID, depositJSON)
	if err != nil {
		return fmt.Errorf("failed to update guarantee deposit in ledger: %v", err)
	}

	// Store updated fund
	guaranteeFundJSON, err := json.Marshal(guaranteeFund)
	if err != nil {
		return fmt.Errorf("failed to marshal guarantee fund: %v", err)
	}

	err = ctx.GetStub().PutState("guaranteeFund", guaranteeFundJSON)
	if err != nil {
		return fmt.Errorf("failed to update guarantee fund in ledger: %v", err)
	}

	// Compensate the affected counterparty
	var counterpartyID string
	if failureReason == "buyer_insufficient_funds" {
		counterpartyID = instruction.SellBrokerID
	} else {
		counterpartyID = instruction.BuyBrokerID
	}

	counterpartyAccount, err := s.GetBrokerAccount(ctx, counterpartyID)
	if err != nil {
		// If counterparty account doesn't exist, create it
		err = s.CreateBrokerAccount(ctx, counterpartyID, 0)
		if err != nil {
			return fmt.Errorf("failed to create counterparty broker account: %v", err)
		}
		counterpartyAccount, err = s.GetBrokerAccount(ctx, counterpartyID)
		if err != nil {
			return fmt.Errorf("failed to get counterparty broker account: %v", err)
		}
	}

	// Add compensation to counterparty
	counterpartyAccount.Balance += (amountFromDeposit + amountFromFund)
	counterpartyAccount.LastUpdated = currentTime

	counterpartyAccountJSON, err := json.Marshal(counterpartyAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal counterparty broker account: %v", err)
	}

	err = ctx.GetStub().PutState("brokerAccount-"+counterpartyID, counterpartyAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to update counterparty broker account in ledger: %v", err)
	}

	// Record the compensation transaction
	compensationTransactionID := "transaction-compensation-" + instruction.InstructionID
	compensationTransaction := Transaction{
		TransactionID: compensationTransactionID,
		Type:          "compensation",
		FromID:        "guarantee", // Indicate it's from the guarantee system
		ToID:          counterpartyID,
		SecurityID:    "",
		Amount:        amountFromDeposit + amountFromFund,
		InstructionID: instruction.InstructionID,
		Status:        "completed",
		Timestamp:     currentTime,
	}

	compensationTransactionJSON, err := json.Marshal(compensationTransaction)
	if err != nil {
		return fmt.Errorf("failed to marshal compensation transaction: %v", err)
	}

	err = ctx.GetStub().PutState(compensationTransactionID, compensationTransactionJSON)
	if err != nil {
		return fmt.Errorf("failed to save compensation transaction in ledger: %v", err)
	}

	// Emit an event for the settlement failure
	failureEvent := struct {
		InstructionID      string  `json:"instructionID"`
		FailureReason      string  `json:"failureReason"`
		DefaultingBroker   string  `json:"defaultingBroker"`
		Counterparty       string  `json:"counterparty"`
		CompensationAmount float64 `json:"compensationAmount"`
		Timestamp          string  `json:"timestamp"`
	}{
		InstructionID:      instructionID,
		FailureReason:      failureReason,
		DefaultingBroker:   defaultingBrokerID,
		Counterparty:       counterpartyID,
		CompensationAmount: amountFromDeposit + amountFromFund,
		Timestamp:          currentTime,
	}

	failureEventJSON, err := json.Marshal(failureEvent)
	if err != nil {
		return fmt.Errorf("failed to marshal failure event: %v", err)
	}

	err = ctx.GetStub().SetEvent("SettlementFailed", failureEventJSON)
	if err != nil {
		return fmt.Errorf("failed to set SettlementFailed event: %v", err)
	}

	return nil
}

// GetTransactionHistory retrieves all transactions for a broker
func (s *SettlementContract) GetTransactionHistory(ctx contractapi.TransactionContextInterface, brokerID string) ([]*Transaction, error) {
	// Get all transactions
	resultsIterator, err := ctx.GetStub().GetStateByRange("transaction-", "transaction-~")
	if err != nil {
		return nil, fmt.Errorf("failed to get transactions: %v", err)
	}
	defer resultsIterator.Close()

	var transactions []*Transaction
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to iterate transactions: %v", err)
		}

		var transaction Transaction
		err = json.Unmarshal(queryResponse.Value, &transaction)
		if err != nil {
			continue // Skip if not a valid Transaction
		}

		// Filter by brokerID (either as sender or receiver)
		if transaction.FromID == brokerID || transaction.ToID == brokerID {
			transactions = append(transactions, &transaction)
		}
	}

	return transactions, nil
}

// GetPendingSettlementInstructions retrieves all pending settlement instructions
func (s *SettlementContract) GetPendingSettlementInstructions(ctx contractapi.TransactionContextInterface) ([]*SettlementInstruction, error) {
	// Get all instructions
	resultsIterator, err := ctx.GetStub().GetStateByRange("instruction-", "instruction-~")
	if err != nil {
		return nil, fmt.Errorf("failed to get instructions: %v", err)
	}
	defer resultsIterator.Close()

	var instructions []*SettlementInstruction
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to iterate instructions: %v", err)
		}

		var instruction SettlementInstruction
		err = json.Unmarshal(queryResponse.Value, &instruction)
		if err != nil {
			continue // Skip if not a valid SettlementInstruction
		}

		// Filter by status
		if instruction.Status == "pending" || instruction.Status == "validated" {
			instructions = append(instructions, &instruction)
		}
	}

	return instructions, nil
}

// BatchSettlement processes all pending settlements that are due
func (s *SettlementContract) BatchSettlement(ctx contractapi.TransactionContextInterface) error {
	// Get all pending instructions
	pendingInstructions, err := s.GetPendingSettlementInstructions(ctx)
	if err != nil {
		return fmt.Errorf("failed to get pending instructions: %v", err)
	}

	// Current time for comparison
	currentTime := time.Now()

	// Process each instruction that is due for settlement
	for _, instruction := range pendingInstructions {
		// Parse settlement date
		settlementDate, err := time.Parse(time.RFC3339, instruction.SettlementDate)
		if err != nil {
			continue // Skip if date can't be parsed
		}

		// Execute settlement if due or past due
		if !currentTime.Before(settlementDate) {
			err = s.ExecuteSettlement(ctx, instruction.InstructionID)
			if err != nil {
				// Log error but continue with other settlements
				fmt.Printf("Failed to execute settlement for instruction %s: %v\n", instruction.InstructionID, err)
			}
		}
	}

	return nil
}

// DepositFunds deposits funds to a broker's account
func (s *SettlementContract) DepositFunds(ctx contractapi.TransactionContextInterface, brokerID string, amount float64) error {
	if amount <= 0 {
		return fmt.Errorf("deposit amount must be positive")
	}

	// Get or create broker account
	brokerAccount, err := s.GetBrokerAccount(ctx, brokerID)
	if err != nil {
		// If account doesn't exist, create it
		err = s.CreateBrokerAccount(ctx, brokerID, 0)
		if err != nil {
			return fmt.Errorf("failed to create broker account: %v", err)
		}
		brokerAccount, err = s.GetBrokerAccount(ctx, brokerID)
		if err != nil {
			return fmt.Errorf("failed to get broker account: %v", err)
		}
	}

	// Update balance
	brokerAccount.Balance += amount
	brokerAccount.LastUpdated = time.Now().Format(time.RFC3339)

	// Store updated account
	brokerAccountJSON, err := json.Marshal(brokerAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal broker account: %v", err)
	}

	err = ctx.GetStub().PutState("brokerAccount-"+brokerID, brokerAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to update broker account in ledger: %v", err)
	}

	// Record deposit transaction
	depositTransactionID := fmt.Sprintf("transaction-deposit-%s-%d", brokerID, time.Now().UnixNano())
	depositTransaction := Transaction{
		TransactionID: depositTransactionID,
		Type:          "deposit",
		FromID:        "external",
		ToID:          brokerID,
		SecurityID:    "",
		Amount:        amount,
		InstructionID: "",
		Status:        "completed",
		Timestamp:     brokerAccount.LastUpdated,
	}

	depositTransactionJSON, err := json.Marshal(depositTransaction)
	if err != nil {
		return fmt.Errorf("failed to marshal deposit transaction: %v", err)
	}

	err = ctx.GetStub().PutState(depositTransactionID, depositTransactionJSON)
	if err != nil {
		return fmt.Errorf("failed to save deposit transaction in ledger: %v", err)
	}

	return nil
}

// WithdrawFunds withdraws funds from a broker's account
func (s *SettlementContract) WithdrawFunds(ctx contractapi.TransactionContextInterface, brokerID string, amount float64) error {
	if amount <= 0 {
		return fmt.Errorf("withdrawal amount must be positive")
	}

	// Get broker account
	brokerAccount, err := s.GetBrokerAccount(ctx, brokerID)
	if err != nil {
		return fmt.Errorf("failed to get broker account: %v", err)
	}

	// Check available balance
	availableBalance := brokerAccount.Balance - brokerAccount.ReservedBalance
	if availableBalance < amount {
		return fmt.Errorf("insufficient available balance for withdrawal")
	}

	// Update balance
	brokerAccount.Balance -= amount
	brokerAccount.LastUpdated = time.Now().Format(time.RFC3339)

	// Store updated account
	brokerAccountJSON, err := json.Marshal(brokerAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal broker account: %v", err)
	}

	err = ctx.GetStub().PutState("brokerAccount-"+brokerID, brokerAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to update broker account in ledger: %v", err)
	}

	// Record withdrawal transaction
	withdrawalTransactionID := fmt.Sprintf("transaction-withdrawal-%s-%d", brokerID, time.Now().UnixNano())
	withdrawalTransaction := Transaction{
		TransactionID: withdrawalTransactionID,
		Type:          "withdrawal",
		FromID:        brokerID,
		ToID:          "external",
		SecurityID:    "",
		Amount:        amount,
		InstructionID: "",
		Status:        "completed",
		Timestamp:     brokerAccount.LastUpdated,
	}

	withdrawalTransactionJSON, err := json.Marshal(withdrawalTransaction)
	if err != nil {
		return fmt.Errorf("failed to marshal withdrawal transaction: %v", err)
	}

	err = ctx.GetStub().PutState(withdrawalTransactionID, withdrawalTransactionJSON)
	if err != nil {
		return fmt.Errorf("failed to save withdrawal transaction in ledger: %v", err)
	}

	return nil
}

// DepositSecurities deposits securities to a broker's securities account
func (s *SettlementContract) DepositSecurities(ctx contractapi.TransactionContextInterface, brokerID, securityID string, quantity int) error {
	if quantity <= 0 {
		return fmt.Errorf("deposit quantity must be positive")
	}

	// Get or create securities account
	securitiesAccount, err := s.GetSecuritiesAccount(ctx, brokerID, securityID)
	if err != nil {
		// If account doesn't exist, create it
		err = s.CreateSecuritiesAccount(ctx, brokerID, securityID, 0)
		if err != nil {
			return fmt.Errorf("failed to create securities account: %v", err)
		}
		securitiesAccount, err = s.GetSecuritiesAccount(ctx, brokerID, securityID)
		if err != nil {
			return fmt.Errorf("failed to get securities account: %v", err)
		}
	}

	// Update quantity
	securitiesAccount.Quantity += quantity
	securitiesAccount.LastUpdated = time.Now().Format(time.RFC3339)

	// Store updated account
	securitiesAccountJSON, err := json.Marshal(securitiesAccount)
	if err != nil {
		return fmt.Errorf("failed to marshal securities account: %v", err)
	}

	err = ctx.GetStub().PutState(securitiesAccount.AccountID, securitiesAccountJSON)
	if err != nil {
		return fmt.Errorf("failed to update securities account in ledger: %v", err)
	}

	// Record deposit transaction
	depositTransactionID := fmt.Sprintf("transaction-sec-deposit-%s-%s-%d", brokerID, securityID, time.Now().UnixNano())
	depositTransaction := Transaction{
		TransactionID: depositTransactionID,
		Type:          "security_deposit",
		FromID:        "external",
		ToID:          brokerID,
		SecurityID:    securityID,
		Amount:        float64(quantity),
		InstructionID: "",
		Status:        "completed",
		Timestamp:     securitiesAccount.LastUpdated,
	}

	depositTransactionJSON, err := json.Marshal(depositTransaction)
	if err != nil {
		return fmt.Errorf("failed to marshal securities deposit transaction: %v", err)
	}

	err = ctx.GetStub().PutState(depositTransactionID, depositTransactionJSON)
	if err != nil {
		return fmt.Errorf("failed to save securities deposit transaction in ledger: %v", err)
	}

	return nil
}

func (s *SettlementContract) ImportTrade(ctx contractapi.TransactionContextInterface,
	tradeID, buyOrderID, sellOrderID, buyBrokerID, sellBrokerID, securityID string,
	quantity int, price float64, status, matchTime string) error {

	trade := Trade{
		TradeID:      tradeID,
		BuyOrderID:   buyOrderID,
		SellOrderID:  sellOrderID,
		BuyBrokerID:  buyBrokerID,
		SellBrokerID: sellBrokerID,
		SecurityID:   securityID,
		Quantity:     quantity,
		Price:        price,
		Status:       status,
		MatchTime:    matchTime,
	}

	tradeJSON, err := json.Marshal(trade)
	if err != nil {
		return fmt.Errorf("failed to marshal trade: %v", err)
	}

	return ctx.GetStub().PutState(tradeID, tradeJSON)
}

func main() {
	chaincode, err := contractapi.NewChaincode(&SettlementContract{})
	if err != nil {
		fmt.Printf("Error creating settlement chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting settlement chaincode: %s", err.Error())
	}
}
