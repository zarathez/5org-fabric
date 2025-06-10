// compliance.go - Updated to match the new architecture
package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// ComplianceContract provides regulatory functions for validating market trades
type ComplianceContract struct {
	contractapi.Contract
}

// Trade represents a matched trade from the order matching chaincode
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

// ComplianceCheck represents a regulatory check on a trade
type ComplianceCheck struct {
	CheckID         string          `json:"checkID"`
	TradeID         string          `json:"tradeID"`
	Status          string          `json:"status"` // pending, approved, rejected
	RejectionReason string          `json:"rejectionReason"`
	Rules           map[string]bool `json:"rules"`
	Comments        string          `json:"comments"`
	RegulatorID     string          `json:"regulatorID"`
	CheckTime       string          `json:"checkTime"`
	UpdateTime      string          `json:"updateTime"`
}

// Security represents a stock with its regulatory information
type Security struct {
	SecurityID            string  `json:"securityID"`
	Symbol                string  `json:"symbol"`
	Name                  string  `json:"name"`
	IssuerID              string  `json:"issuerID"`
	TotalShares           int     `json:"totalShares"`
	PriceLimit            float64 `json:"priceLimit"`
	DailyPriceChangeLimit float64 `json:"dailyPriceChangeLimit"` // in percentage
	RequiresSpecialCheck  bool    `json:"requiresSpecialCheck"`
	Status                string  `json:"status"` // active, suspended, delisted
	LastPrice             float64 `json:"lastPrice"`
	CreatedAt             string  `json:"createdAt"`
	UpdatedAt             string  `json:"updatedAt"`
}

// Broker represents a broker with regulatory information
type Broker struct {
	BrokerID             string  `json:"brokerID"`
	Name                 string  `json:"name"`
	Status               string  `json:"status"` // active, suspended, revoked
	TradeLimit           float64 `json:"tradeLimit"`
	RiskRating           string  `json:"riskRating"` // low, medium, high
	ComplianceViolations int     `json:"complianceViolations"`
	LastUpdated          string  `json:"lastUpdated"`
}

// Rule represents a compliance rule
type Rule struct {
	RuleID      string `json:"ruleID"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Status      string `json:"status"`   // active, inactive
	Severity    string `json:"severity"` // low, medium, high, critical
	Category    string `json:"category"` // price, volume, broker, security
	CreatedAt   string `json:"createdAt"`
	UpdatedAt   string `json:"updatedAt"`
}

func (c *ComplianceContract) ImportTrade(ctx contractapi.TransactionContextInterface,
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

// InitLedger initializes the ledger with sample compliance rules
func (c *ComplianceContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	// Initialize basic compliance rules
	rules := []Rule{
		{
			RuleID:      "RULE001",
			Name:        "Price Manipulation Check",
			Description: "Checks if trade price is within acceptable range of market price",
			Status:      "active",
			Severity:    "high",
			Category:    "price",
			CreatedAt:   time.Now().Format(time.RFC3339),
			UpdatedAt:   time.Now().Format(time.RFC3339),
		},
		{
			RuleID:      "RULE002",
			Name:        "Broker Eligibility Check",
			Description: "Verifies that brokers are in good standing",
			Status:      "active",
			Severity:    "critical",
			Category:    "broker",
			CreatedAt:   time.Now().Format(time.RFC3339),
			UpdatedAt:   time.Now().Format(time.RFC3339),
		},
		{
			RuleID:      "RULE003",
			Name:        "Volume Check",
			Description: "Checks if trade volume is suspicious",
			Status:      "active",
			Severity:    "medium",
			Category:    "volume",
			CreatedAt:   time.Now().Format(time.RFC3339),
			UpdatedAt:   time.Now().Format(time.RFC3339),
		},
		{
			RuleID:      "RULE004",
			Name:        "Security Status Check",
			Description: "Verifies that the security is active and not suspended",
			Status:      "active",
			Severity:    "critical",
			Category:    "security",
			CreatedAt:   time.Now().Format(time.RFC3339),
			UpdatedAt:   time.Now().Format(time.RFC3339),
		},
	}

	for _, rule := range rules {
		ruleJSON, err := json.Marshal(rule)
		if err != nil {
			return fmt.Errorf("failed to marshal rule: %v", err)
		}

		err = ctx.GetStub().PutState(rule.RuleID, ruleJSON)
		if err != nil {
			return fmt.Errorf("failed to put rule in world state: %v", err)
		}
	}

	return nil
}

// AddSecurity adds a new security to the ledger with its compliance information
func (c *ComplianceContract) AddSecurity(ctx contractapi.TransactionContextInterface, securityID, symbol, name, issuerID string, totalShares int, priceLimit, dailyPriceChangeLimit float64, requiresSpecialCheck bool) error {
	// Check if the security already exists
	securityJSON, err := ctx.GetStub().GetState(securityID)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if securityJSON != nil {
		return fmt.Errorf("security %s already exists", securityID)
	}

	// Create security object
	currentTime := time.Now().Format(time.RFC3339)
	security := Security{
		SecurityID:            securityID,
		Symbol:                symbol,
		Name:                  name,
		IssuerID:              issuerID,
		TotalShares:           totalShares,
		PriceLimit:            priceLimit,
		DailyPriceChangeLimit: dailyPriceChangeLimit,
		RequiresSpecialCheck:  requiresSpecialCheck,
		Status:                "active",
		LastPrice:             0,
		CreatedAt:             currentTime,
		UpdatedAt:             currentTime,
	}

	// Store the security in the ledger
	securityJSON, err = json.Marshal(security)
	if err != nil {
		return fmt.Errorf("failed to marshal security: %v", err)
	}

	err = ctx.GetStub().PutState(securityID, securityJSON)
	if err != nil {
		return fmt.Errorf("failed to put security in ledger: %v", err)
	}

	return nil
}

// GetSecurity retrieves a security by ID
func (c *ComplianceContract) GetSecurity(ctx contractapi.TransactionContextInterface, securityID string) (*Security, error) {
	securityJSON, err := ctx.GetStub().GetState(securityID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if securityJSON == nil {
		return nil, fmt.Errorf("security %s does not exist", securityID)
	}

	var security Security
	err = json.Unmarshal(securityJSON, &security)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal security: %v", err)
	}

	return &security, nil
}

// UpdateSecurityStatus updates a security's status
func (c *ComplianceContract) UpdateSecurityStatus(ctx contractapi.TransactionContextInterface, securityID, newStatus string) error {
	security, err := c.GetSecurity(ctx, securityID)
	if err != nil {
		return err
	}

	// Validate status
	if newStatus != "active" && newStatus != "suspended" && newStatus != "delisted" {
		return fmt.Errorf("invalid status: must be 'active', 'suspended', or 'delisted'")
	}

	// Update security status
	security.Status = newStatus
	security.UpdatedAt = time.Now().Format(time.RFC3339)

	// Store the updated security
	securityJSON, err := json.Marshal(security)
	if err != nil {
		return fmt.Errorf("failed to marshal security: %v", err)
	}

	err = ctx.GetStub().PutState(securityID, securityJSON)
	if err != nil {
		return fmt.Errorf("failed to update security in ledger: %v", err)
	}

	return nil
}

// AddBroker adds a new broker to the ledger with regulatory information
func (c *ComplianceContract) AddBroker(ctx contractapi.TransactionContextInterface, brokerID, name string, tradeLimit float64, riskRating string) error {
	// Check if the broker already exists
	brokerJSON, err := ctx.GetStub().GetState("broker-" + brokerID)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if brokerJSON != nil {
		return fmt.Errorf("broker %s already exists", brokerID)
	}

	// Validate riskRating
	if riskRating != "low" && riskRating != "medium" && riskRating != "high" {
		return fmt.Errorf("invalid risk rating: must be 'low', 'medium', or 'high'")
	}

	// Create broker object
	currentTime := time.Now().Format(time.RFC3339)
	broker := Broker{
		BrokerID:             brokerID,
		Name:                 name,
		Status:               "active",
		TradeLimit:           tradeLimit,
		RiskRating:           riskRating,
		ComplianceViolations: 0,
		LastUpdated:          currentTime,
	}

	// Store the broker in the ledger
	brokerJSON, err = json.Marshal(broker)
	if err != nil {
		return fmt.Errorf("failed to marshal broker: %v", err)
	}

	err = ctx.GetStub().PutState("broker-"+brokerID, brokerJSON)
	if err != nil {
		return fmt.Errorf("failed to put broker in ledger: %v", err)
	}

	return nil
}

// GetBroker retrieves a broker by ID
func (c *ComplianceContract) GetBroker(ctx contractapi.TransactionContextInterface, brokerID string) (*Broker, error) {
	brokerJSON, err := ctx.GetStub().GetState("broker-" + brokerID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if brokerJSON == nil {
		return nil, fmt.Errorf("broker %s does not exist", brokerID)
	}

	var broker Broker
	err = json.Unmarshal(brokerJSON, &broker)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal broker: %v", err)
	}

	return &broker, nil
}

// UpdateBrokerStatus updates a broker's status
func (c *ComplianceContract) UpdateBrokerStatus(ctx contractapi.TransactionContextInterface, brokerID, newStatus string) error {
	broker, err := c.GetBroker(ctx, brokerID)
	if err != nil {
		return err
	}

	// Validate status
	if newStatus != "active" && newStatus != "suspended" && newStatus != "revoked" {
		return fmt.Errorf("invalid status: must be 'active', 'suspended', or 'revoked'")
	}

	// Update broker status
	broker.Status = newStatus
	broker.LastUpdated = time.Now().Format(time.RFC3339)

	// Store the updated broker
	brokerJSON, err := json.Marshal(broker)
	if err != nil {
		return fmt.Errorf("failed to marshal broker: %v", err)
	}

	err = ctx.GetStub().PutState("broker-"+brokerID, brokerJSON)
	if err != nil {
		return fmt.Errorf("failed to update broker in ledger: %v", err)
	}

	return nil
}

// AddRule adds a new compliance rule
func (c *ComplianceContract) AddRule(ctx contractapi.TransactionContextInterface, ruleID, name, description, status, severity, category string) error {
	// Check if the rule already exists
	ruleJSON, err := ctx.GetStub().GetState(ruleID)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if ruleJSON != nil {
		return fmt.Errorf("rule %s already exists", ruleID)
	}

	// Validate status
	if status != "active" && status != "inactive" {
		return fmt.Errorf("invalid status: must be 'active' or 'inactive'")
	}

	// Validate severity
	if severity != "low" && severity != "medium" && severity != "high" && severity != "critical" {
		return fmt.Errorf("invalid severity: must be 'low', 'medium', 'high', or 'critical'")
	}

	// Create rule object
	currentTime := time.Now().Format(time.RFC3339)
	rule := Rule{
		RuleID:      ruleID,
		Name:        name,
		Description: description,
		Status:      status,
		Severity:    severity,
		Category:    category,
		CreatedAt:   currentTime,
		UpdatedAt:   currentTime,
	}

	// Store the rule in the ledger
	ruleJSON, err = json.Marshal(rule)
	if err != nil {
		return fmt.Errorf("failed to marshal rule: %v", err)
	}

	err = ctx.GetStub().PutState(ruleID, ruleJSON)
	if err != nil {
		return fmt.Errorf("failed to put rule in ledger: %v", err)
	}

	return nil
}

// GetRule retrieves a rule by ID
func (c *ComplianceContract) GetRule(ctx contractapi.TransactionContextInterface, ruleID string) (*Rule, error) {
	ruleJSON, err := ctx.GetStub().GetState(ruleID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if ruleJSON == nil {
		return nil, fmt.Errorf("rule %s does not exist", ruleID)
	}

	var rule Rule
	err = json.Unmarshal(ruleJSON, &rule)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal rule: %v", err)
	}

	return &rule, nil
}

// GetAllRules retrieves all compliance rules
func (c *ComplianceContract) GetAllRules(ctx contractapi.TransactionContextInterface) ([]*Rule, error) {
	// Get all rules
	resultsIterator, err := ctx.GetStub().GetStateByRange("RULE", "RULE~")
	if err != nil {
		return nil, fmt.Errorf("failed to get rules: %v", err)
	}
	defer resultsIterator.Close()

	var rules []*Rule
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to iterate rules: %v", err)
		}

		var rule Rule
		err = json.Unmarshal(queryResponse.Value, &rule)
		if err != nil {
			continue // Skip if not a valid Rule
		}

		rules = append(rules, &rule)
	}

	return rules, nil
}

// PerformTradeCheck performs compliance checks on a trade
func (c *ComplianceContract) PerformTradeCheck(ctx contractapi.TransactionContextInterface, tradeID, regulatorID string) error {
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

	// Check if a compliance check already exists for this trade
	checkID := "check-" + tradeID
	checkJSON, err := ctx.GetStub().GetState(checkID)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if checkJSON != nil {
		return fmt.Errorf("compliance check for trade %s already exists", tradeID)
	}

	// Get security information
	security, err := c.GetSecurity(ctx, trade.SecurityID)
	if err != nil {
		return fmt.Errorf("failed to get security info: %v", err)
	}

	// Get buyer broker information
	buyBroker, err := c.GetBroker(ctx, trade.BuyBrokerID)
	if err != nil {
		return fmt.Errorf("failed to get buyer broker info: %v", err)
	}

	// Get seller broker information
	sellBroker, err := c.GetBroker(ctx, trade.SellBrokerID)
	if err != nil {
		return fmt.Errorf("failed to get seller broker info: %v", err)
	}

	// Perform all compliance checks
	ruleResults := make(map[string]bool)
	var rejectionReason string
	allPassed := true

	// 1. Check security status (RULE004)
	ruleResults["RULE004"] = security.Status == "active"
	if !ruleResults["RULE004"] {
		allPassed = false
		rejectionReason = "Security is not active for trading"
	}

	// 2. Check broker eligibility (RULE002)
	buyerBrokerStatusOK := buyBroker.Status == "active"
	sellerBrokerStatusOK := sellBroker.Status == "active"
	ruleResults["RULE002"] = buyerBrokerStatusOK && sellerBrokerStatusOK
	if !ruleResults["RULE002"] && allPassed {
		allPassed = false
		rejectionReason = "One or both brokers are not active"
	}

	// 3. Check price manipulation (RULE001)
	priceOK := true
	if security.LastPrice > 0 {
		// Calculate percentage change
		pctChange := ((trade.Price - security.LastPrice) / security.LastPrice) * 100
		if pctChange < -security.DailyPriceChangeLimit || pctChange > security.DailyPriceChangeLimit {
			priceOK = false
		}
	}
	ruleResults["RULE001"] = priceOK
	if !ruleResults["RULE001"] && allPassed {
		allPassed = false
		rejectionReason = "Price deviation exceeds allowed limit"
	}

	// 4. Check volume (RULE003)
	volumeOK := trade.Quantity <= int(buyBroker.TradeLimit) && trade.Quantity <= int(sellBroker.TradeLimit)
	ruleResults["RULE003"] = volumeOK
	if !ruleResults["RULE003"] && allPassed {
		allPassed = false
		rejectionReason = "Trade volume exceeds broker's limit"
	}

	// 5. Special checks if needed
	if security.RequiresSpecialCheck && allPassed {
		// For stocks requiring special attention, risk rating of both brokers should be low
		specialCheckOK := buyBroker.RiskRating == "low" && sellBroker.RiskRating == "low"
		if !specialCheckOK {
			allPassed = false
			rejectionReason = "Special security requires low-risk brokers"
		}
	}

	// Create compliance check record
	currentTime := time.Now().Format(time.RFC3339)
	status := "approved"
	if !allPassed {
		status = "rejected"
	}

	complianceCheck := ComplianceCheck{
		CheckID:         checkID,
		TradeID:         tradeID,
		Status:          status,
		RejectionReason: rejectionReason,
		Rules:           ruleResults,
		Comments:        "",
		RegulatorID:     regulatorID,
		CheckTime:       currentTime,
		UpdateTime:      currentTime,
	}

	// Store the compliance check
	checkJSON, err = json.Marshal(complianceCheck)
	if err != nil {
		return fmt.Errorf("failed to marshal compliance check: %v", err)
	}

	err = ctx.GetStub().PutState(checkID, checkJSON)
	if err != nil {
		return fmt.Errorf("failed to put compliance check in ledger: %v", err)
	}

	// Update trade status based on compliance check
	trade.Status = status
	tradeJSON, err = json.Marshal(trade)
	if err != nil {
		return fmt.Errorf("failed to marshal trade: %v", err)
	}

	err = ctx.GetStub().PutState(tradeID, tradeJSON)
	if err != nil {
		return fmt.Errorf("failed to update trade in ledger: %v", err)
	}

	// If rejected, update broker compliance violations
	if status == "rejected" {
		// Update both brokers' violation count
		buyBroker.ComplianceViolations++
		buyBroker.LastUpdated = currentTime

		sellBroker.ComplianceViolations++
		sellBroker.LastUpdated = currentTime

		// Store updated brokers
		buyBrokerJSON, err := json.Marshal(buyBroker)
		if err != nil {
			return fmt.Errorf("failed to marshal buy broker: %v", err)
		}

		err = ctx.GetStub().PutState("broker-"+trade.BuyBrokerID, buyBrokerJSON)
		if err != nil {
			return fmt.Errorf("failed to update buy broker: %v", err)
		}

		sellBrokerJSON, err := json.Marshal(sellBroker)
		if err != nil {
			return fmt.Errorf("failed to marshal sell broker: %v", err)
		}

		err = ctx.GetStub().PutState("broker-"+trade.SellBrokerID, sellBrokerJSON)
		if err != nil {
			return fmt.Errorf("failed to update sell broker: %v", err)
		}
	}

	// If approved, update security's last price
	if status == "approved" {
		security.LastPrice = trade.Price
		security.UpdatedAt = currentTime

		securityJSON, err := json.Marshal(security)
		if err != nil {
			return fmt.Errorf("failed to marshal security: %v", err)
		}

		err = ctx.GetStub().PutState(trade.SecurityID, securityJSON)
		if err != nil {
			return fmt.Errorf("failed to update security in ledger: %v", err)
		}
	}

	// Emit an event for the compliance check
	err = ctx.GetStub().SetEvent("ComplianceCheckCompleted", checkJSON)
	if err != nil {
		return fmt.Errorf("failed to set ComplianceCheckCompleted event: %v", err)
	}

	return nil
}

// GetComplianceCheck retrieves a compliance check by ID
func (c *ComplianceContract) GetComplianceCheck(ctx contractapi.TransactionContextInterface, checkID string) (*ComplianceCheck, error) {
	checkJSON, err := ctx.GetStub().GetState(checkID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if checkJSON == nil {
		return nil, fmt.Errorf("compliance check %s does not exist", checkID)
	}

	var check ComplianceCheck
	err = json.Unmarshal(checkJSON, &check)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal compliance check: %v", err)
	}

	return &check, nil
}

// ManualOverrideComplianceCheck allows a regulator to manually override a compliance check
func (c *ComplianceContract) ManualOverrideComplianceCheck(ctx contractapi.TransactionContextInterface, checkID, newStatus, comments, regulatorID string) error {
	check, err := c.GetComplianceCheck(ctx, checkID)
	if err != nil {
		return err
	}

	// Validate status
	if newStatus != "approved" && newStatus != "rejected" {
		return fmt.Errorf("invalid status: must be 'approved' or 'rejected'")
	}

	// Update check
	check.Status = newStatus
	check.Comments = comments
	check.RegulatorID = regulatorID
	check.UpdateTime = time.Now().Format(time.RFC3339)

	if newStatus == "rejected" && check.RejectionReason == "" {
		check.RejectionReason = "Manual rejection by regulator"
	}

	// Store the updated check
	checkJSON, err := json.Marshal(check)
	if err != nil {
		return fmt.Errorf("failed to marshal compliance check: %v", err)
	}

	err = ctx.GetStub().PutState(checkID, checkJSON)
	if err != nil {
		return fmt.Errorf("failed to update compliance check in ledger: %v", err)
	}

	// Update the corresponding trade
	tradeJSON, err := ctx.GetStub().GetState(check.TradeID)
	if err != nil {
		return fmt.Errorf("failed to read trade from world state: %v", err)
	}
	if tradeJSON == nil {
		return fmt.Errorf("trade %s does not exist", check.TradeID)
	}

	var trade Trade
	err = json.Unmarshal(tradeJSON, &trade)
	if err != nil {
		return fmt.Errorf("failed to unmarshal trade: %v", err)
	}

	trade.Status = newStatus
	tradeJSON, err = json.Marshal(trade)
	if err != nil {
		return fmt.Errorf("failed to marshal trade: %v", err)
	}

	err = ctx.GetStub().PutState(check.TradeID, tradeJSON)
	if err != nil {
		return fmt.Errorf("failed to update trade in ledger: %v", err)
	}

	// Emit an event for the compliance check override
	err = ctx.GetStub().SetEvent("ComplianceCheckOverridden", checkJSON)
	if err != nil {
		return fmt.Errorf("failed to set ComplianceCheckOverridden event: %v", err)
	}

	return nil
}

// GetTrade retrieves a trade by ID
func (c *ComplianceContract) GetTrade(ctx contractapi.TransactionContextInterface, tradeID string) (*Trade, error) {
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

func main() {
	chaincode, err := contractapi.NewChaincode(&ComplianceContract{})
	if err != nil {
		fmt.Printf("Error creating compliance chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting compliance chaincode: %s", err.Error())
	}
}
