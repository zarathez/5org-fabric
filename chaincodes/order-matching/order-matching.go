// order-matching.go - Updated to match the new architecture
package main

import (
	"encoding/json"
	"fmt"
	"sort"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// OrderMatchingContract provides functions for managing orders and matches
type OrderMatchingContract struct {
	contractapi.Contract
}

// Security represents a listed security in the stock market
type Security struct {
	SecurityID     string    `json:"securityID"`
	Symbol         string    `json:"symbol"`
	IssuerID       string    `json:"issuerID"`
	Name           string    `json:"name"`
	TotalShares    int       `json:"totalShares"`
	CurrentPrice   float64   `json:"currentPrice"`
	PriceHistory   []float64 `json:"priceHistory"`
	Status         string    `json:"status"` // active, suspended, delisted
	LastUpdateTime string    `json:"lastUpdateTime"`
}

// Order represents a buy or sell order in the stock market
type Order struct {
	OrderID      string  `json:"orderID"`
	BrokerID     string  `json:"brokerID"`
	SecurityID   string  `json:"securityID"`
	Side         string  `json:"side"` // buy or sell
	Quantity     int     `json:"quantity"`
	Price        float64 `json:"price"`
	Status       string  `json:"status"` // pending, matched, executed, canceled
	CreateTime   string  `json:"createTime"`
	UpdateTime   string  `json:"updateTime"`
	RemainingQty int     `json:"remainingQty"`
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
	Status       string  `json:"status"` // pending, settled
	MatchTime    string  `json:"matchTime"`
}

// function to get the caller's organization
func (c *OrderMatchingContract) getClientOrgID(ctx contractapi.TransactionContextInterface) (string, error) {
	// Get client identity directly from the context
	clientID := ctx.GetClientIdentity()
	// Get the MSP ID from the client identity
	mspID, err := clientID.GetMSPID()
	if err != nil {
		return "", fmt.Errorf("failed to get MSP ID: %v", err)
	}

	return mspID, nil
}

// InitLedger initializes the ledger with sample data
func (c *OrderMatchingContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	// Initialize with empty data
	return nil
}

// CreateSecurity creates a new security in the ledger
func (c *OrderMatchingContract) CreateSecurity(ctx contractapi.TransactionContextInterface, securityID, symbol, issuerID, name string, totalShares int, initialPrice float64) error {
	exists, err := c.SecurityExists(ctx, securityID)
	if err != nil {
		return fmt.Errorf("failed to check if security exists: %v", err)
	}
	if exists {
		return fmt.Errorf("security %s already exists", securityID)
	}

	security := Security{
		SecurityID:     securityID,
		Symbol:         symbol,
		IssuerID:       issuerID,
		Name:           name,
		TotalShares:    totalShares,
		CurrentPrice:   initialPrice,
		PriceHistory:   []float64{initialPrice},
		Status:         "active",
		LastUpdateTime: time.Now().Format(time.RFC3339),
	}

	securityJSON, err := json.Marshal(security)
	if err != nil {
		return fmt.Errorf("failed to marshal security: %v", err)
	}

	err = ctx.GetStub().PutState(securityID, securityJSON)
	if err != nil {
		return fmt.Errorf("failed to put security in ledger: %v", err)
	}

	return nil
}

// SecurityExists checks if a security with given ID exists
func (c *OrderMatchingContract) SecurityExists(ctx contractapi.TransactionContextInterface, securityID string) (bool, error) {
	securityJSON, err := ctx.GetStub().GetState(securityID)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}
	return securityJSON != nil, nil
}

// GetSecurity retrieves a security by ID
func (c *OrderMatchingContract) GetSecurity(ctx contractapi.TransactionContextInterface, securityID string) (*Security, error) {
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
func (c *OrderMatchingContract) UpdateSecurityStatus(ctx contractapi.TransactionContextInterface, securityID, newStatus string) error {

	// Check caller's organization
	mspID, err := c.getClientOrgID(ctx)
	if err != nil {
		return err
	}

	// Only StockMarket can call this function
	if mspID != "StockMarketMSP" {
		return fmt.Errorf("only StockMarket is authorized to update security status")
	}

	security, err := c.GetSecurity(ctx, securityID)
	if err != nil {
		return err
	}

	// Validate status
	if newStatus != "active" && newStatus != "suspended" && newStatus != "delisted" {
		return fmt.Errorf("invalid status: must be 'active', 'suspended', or 'delisted'")
	}

	security.Status = newStatus
	security.LastUpdateTime = time.Now().Format(time.RFC3339)

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

// CreateOrder creates a new order in the ledger
func (c *OrderMatchingContract) CreateOrder(ctx contractapi.TransactionContextInterface, orderID, brokerID, securityID, side string, quantity int, price float64) error {

	// Check caller's organization
	mspID, err := c.getClientOrgID(ctx)
	if err != nil {
		return err
	}

	// Only Brokers can call this function
	if mspID != "Broker1MSP" && mspID != "Broker2MSP" && mspID != "StockMarketMSP" {
		return fmt.Errorf("only Brokers and the stock market are authorized to create orders")
	}

	// Ensure broker can only submit orders for themselves
	if (mspID == "Broker1MSP" && brokerID != "broker1") ||
		(mspID == "Broker2MSP" && brokerID != "broker2") {
		return fmt.Errorf("brokers can only submit orders for themselves")
	}

	// Check if the order already exists
	exists, err := c.OrderExists(ctx, orderID)
	if err != nil {
		return fmt.Errorf("failed to check if order exists: %v", err)
	}
	if exists {
		return fmt.Errorf("order %s already exists", orderID)
	}

	// Validate order type
	if side != "buy" && side != "sell" {
		return fmt.Errorf("order side must be 'buy' or 'sell'")
	}

	// Validate quantity and price
	if quantity <= 0 {
		return fmt.Errorf("quantity must be positive")
	}
	if price <= 0 {
		return fmt.Errorf("price must be positive")
	}

	// Verify the security exists and is active
	security, err := c.GetSecurity(ctx, securityID)
	if err != nil {
		return err
	}
	if security.Status != "active" {
		return fmt.Errorf("security %s is not active for trading", securityID)
	}

	// Create order object
	currentTime := time.Now().Format(time.RFC3339)
	order := Order{
		OrderID:      orderID,
		BrokerID:     brokerID,
		SecurityID:   securityID,
		Side:         side,
		Quantity:     quantity,
		Price:        price,
		Status:       "pending",
		CreateTime:   currentTime,
		UpdateTime:   currentTime,
		RemainingQty: quantity,
	}

	// Store the order in the ledger
	orderJSON, err := json.Marshal(order)
	if err != nil {
		return fmt.Errorf("failed to marshal order: %v", err)
	}

	err = ctx.GetStub().PutState(orderID, orderJSON)
	if err != nil {
		return fmt.Errorf("failed to put order in ledger: %v", err)
	}

	// Emit an event for the new order
	err = ctx.GetStub().SetEvent("OrderCreated", orderJSON)
	if err != nil {
		return fmt.Errorf("failed to set OrderCreated event: %v", err)
	}

	return nil
}

// OrderExists checks if an order with given ID exists
func (c *OrderMatchingContract) OrderExists(ctx contractapi.TransactionContextInterface, orderID string) (bool, error) {
	orderJSON, err := ctx.GetStub().GetState(orderID)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}
	return orderJSON != nil, nil
}

// GetOrder retrieves an order by ID
func (c *OrderMatchingContract) GetOrder(ctx contractapi.TransactionContextInterface, orderID string) (*Order, error) {
	orderJSON, err := ctx.GetStub().GetState(orderID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if orderJSON == nil {
		return nil, fmt.Errorf("order %s does not exist", orderID)
	}

	var order Order
	err = json.Unmarshal(orderJSON, &order)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal order: %v", err)
	}

	// Check caller's organization
	mspID, err := c.getClientOrgID(ctx)
	if err != nil {
		return nil, err
	}

	// StockMarket and AMMC can view all orders
	if mspID == "StockMarketMSP" || mspID == "AMMCMSP" {
		return &order, nil
	}

	// Brokers can only view their own orders
	if (mspID == "Broker1MSP" && order.BrokerID == "broker1") ||
		(mspID == "Broker2MSP" && order.BrokerID == "broker2") {
		return &order, nil
	}

	return nil, fmt.Errorf("not authorized to view this order")
}

// CancelOrder cancels an existing order
func (c *OrderMatchingContract) CancelOrder(ctx contractapi.TransactionContextInterface, orderID string) error {
	order, err := c.GetOrder(ctx, orderID)
	if err != nil {
		return err
	}

	// Check caller's organization
	mspID, err := c.getClientOrgID(ctx)
	if err != nil {
		return err
	}

	// StockMarket can cancel any order
	if mspID == "StockMarketMSP" {
		// Allow continuation
	} else if (mspID == "Broker1MSP" && order.BrokerID == "broker1") ||
		(mspID == "Broker2MSP" && order.BrokerID == "broker2") {
		// Brokers can cancel only their own orders
	} else {
		return fmt.Errorf("not authorized to cancel this order")
	}

	// Check if order can be canceled
	if order.Status != "pending" {
		return fmt.Errorf("only pending orders can be canceled")
	}

	// Update order status
	order.Status = "canceled"
	order.UpdateTime = time.Now().Format(time.RFC3339)

	// Store the updated order
	orderJSON, err := json.Marshal(order)
	if err != nil {
		return fmt.Errorf("failed to marshal order: %v", err)
	}

	err = ctx.GetStub().PutState(orderID, orderJSON)
	if err != nil {
		return fmt.Errorf("failed to update order in ledger: %v", err)
	}

	// Emit an event for the canceled order
	err = ctx.GetStub().SetEvent("OrderCanceled", orderJSON)
	if err != nil {
		return fmt.Errorf("failed to set OrderCanceled event: %v", err)
	}

	return nil
}

// GetAllOrdersBySecurityID gets all active orders for a specific security
func (c *OrderMatchingContract) GetAllOrdersBySecurityID(ctx contractapi.TransactionContextInterface, securityID string) ([]*Order, error) {
	// Get all orders
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, fmt.Errorf("failed to get all orders: %v", err)
	}
	defer resultsIterator.Close()

	var orders []*Order
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to iterate orders: %v", err)
		}

		var order Order
		err = json.Unmarshal(queryResponse.Value, &order)
		if err != nil {
			continue // Skip if not a valid Order
		}

		// Filter by securityID and active status
		if order.SecurityID == securityID && order.Status == "pending" && order.RemainingQty > 0 {
			orders = append(orders, &order)
		}
	}

	return orders, nil
}

// MatchOrders matches buy and sell orders for a specific security
func (c *OrderMatchingContract) MatchOrders(ctx contractapi.TransactionContextInterface, securityID string) error {

	mspID, err := c.getClientOrgID(ctx)
	if err != nil {
		return err
	}

	// Only StockMarket can call this function
	if mspID != "StockMarketMSP" {
		return fmt.Errorf("only StockMarket is authorized to match orders")
	}

	// Get all active orders for the security
	orders, err := c.GetAllOrdersBySecurityID(ctx, securityID)
	if err != nil {
		return fmt.Errorf("failed to get orders for security %s: %v", securityID, err)
	}

	// Separate buy and sell orders
	var buyOrders []*Order
	var sellOrders []*Order

	for _, order := range orders {
		if order.Side == "buy" {
			buyOrders = append(buyOrders, order)
		} else {
			sellOrders = append(sellOrders, order)
		}
	}

	// Sort buy orders by price (highest first) and time (oldest first)
	sort.SliceStable(buyOrders, func(i, j int) bool {
		if buyOrders[i].Price != buyOrders[j].Price {
			return buyOrders[i].Price > buyOrders[j].Price
		}
		return buyOrders[i].CreateTime < buyOrders[j].CreateTime
	})

	// Sort sell orders by price (lowest first) and time (oldest first)
	sort.SliceStable(sellOrders, func(i, j int) bool {
		if sellOrders[i].Price != sellOrders[j].Price {
			return sellOrders[i].Price < sellOrders[j].Price
		}
		return sellOrders[i].CreateTime < sellOrders[j].CreateTime
	})

	// Match orders
	matchCount := 0
	currentTime := time.Now().Format(time.RFC3339)

	for _, buyOrder := range buyOrders {
		// Skip if buy order is fully matched
		if buyOrder.RemainingQty <= 0 {
			continue
		}

		for j, sellOrder := range sellOrders {
			// Skip if sell order is fully matched
			if sellOrder.RemainingQty <= 0 {
				continue
			}

			// Check if orders can be matched
			if buyOrder.Price >= sellOrder.Price {
				// Determine match quantity
				matchQty := min(buyOrder.RemainingQty, sellOrder.RemainingQty)

				// Create matched trade
				tradeID := fmt.Sprintf("trade-%s-%s-%d", buyOrder.OrderID, sellOrder.OrderID, matchCount)
				matchCount++

				trade := Trade{
					TradeID:      tradeID,
					BuyOrderID:   buyOrder.OrderID,
					SellOrderID:  sellOrder.OrderID,
					BuyBrokerID:  buyOrder.BrokerID,
					SellBrokerID: sellOrder.BrokerID,
					SecurityID:   securityID,
					Quantity:     matchQty,
					Price:        sellOrder.Price, // Use sell price (first in the book)
					Status:       "pending",
					MatchTime:    currentTime,
				}

				// Store the matched trade
				tradeJSON, err := json.Marshal(trade)
				if err != nil {
					return fmt.Errorf("failed to marshal matched trade: %v", err)
				}

				err = ctx.GetStub().PutState(tradeID, tradeJSON)
				if err != nil {
					return fmt.Errorf("failed to store matched trade: %v", err)
				}

				// Update order quantities
				buyOrder.RemainingQty -= matchQty
				sellOrder.RemainingQty -= matchQty

				// Update order status if fully matched
				if buyOrder.RemainingQty == 0 {
					buyOrder.Status = "matched"
				}
				if sellOrder.RemainingQty == 0 {
					sellOrder.Status = "matched"
				}

				// Update order timestamps
				buyOrder.UpdateTime = currentTime
				sellOrder.UpdateTime = currentTime

				// Update orders in the ledger
				buyOrderJSON, err := json.Marshal(buyOrder)
				if err != nil {
					return fmt.Errorf("failed to marshal buy order: %v", err)
				}

				err = ctx.GetStub().PutState(buyOrder.OrderID, buyOrderJSON)
				if err != nil {
					return fmt.Errorf("failed to update buy order: %v", err)
				}

				sellOrderJSON, err := json.Marshal(sellOrder)
				if err != nil {
					return fmt.Errorf("failed to marshal sell order: %v", err)
				}

				err = ctx.GetStub().PutState(sellOrder.OrderID, sellOrderJSON)
				if err != nil {
					return fmt.Errorf("failed to update sell order: %v", err)
				}

				// Update security with new price
				security, err := c.GetSecurity(ctx, securityID)
				if err != nil {
					return fmt.Errorf("failed to get security: %v", err)
				}

				security.CurrentPrice = trade.Price
				security.PriceHistory = append(security.PriceHistory, trade.Price)
				security.LastUpdateTime = currentTime

				securityJSON, err := json.Marshal(security)
				if err != nil {
					return fmt.Errorf("failed to marshal security: %v", err)
				}

				err = ctx.GetStub().PutState(securityID, securityJSON)
				if err != nil {
					return fmt.Errorf("failed to update security: %v", err)
				}

				// Emit an event for the match
				err = ctx.GetStub().SetEvent("OrdersMatched", tradeJSON)
				if err != nil {
					return fmt.Errorf("failed to set OrdersMatched event: %v", err)
				}

				// Update sellOrders array
				sellOrders[j] = sellOrder

				// Break if buy order is fully matched
				if buyOrder.RemainingQty == 0 {
					break
				}
			}
		}
	}

	return nil
}

// GetTrade retrieves a trade by ID
func (c *OrderMatchingContract) GetTrade(ctx contractapi.TransactionContextInterface, tradeID string) (*Trade, error) {
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

// GetAllTradesByStatus gets all trades with a specific status
func (c *OrderMatchingContract) GetAllTradesByStatus(ctx contractapi.TransactionContextInterface, status string) ([]*Trade, error) {
	// Get all trades
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, fmt.Errorf("failed to get all trades: %v", err)
	}
	defer resultsIterator.Close()

	var trades []*Trade
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to iterate trades: %v", err)
		}

		// Skip if not a trade (if ID doesn't start with "trade-")
		if len(queryResponse.Key) < 6 || queryResponse.Key[:6] != "trade-" {
			continue
		}

		var trade Trade
		err = json.Unmarshal(queryResponse.Value, &trade)
		if err != nil {
			continue // Skip if not a valid Trade
		}

		// Filter by status
		if trade.Status == status {
			trades = append(trades, &trade)
		}
	}

	return trades, nil
}

// UpdateTradeStatus updates the status of a trade
func (c *OrderMatchingContract) UpdateTradeStatus(ctx contractapi.TransactionContextInterface, tradeID, newStatus string) error {
	trade, err := c.GetTrade(ctx, tradeID)
	if err != nil {
		return err
	}

	// Validate status
	if newStatus != "pending" && newStatus != "approved" && newStatus != "rejected" && newStatus != "settled" {
		return fmt.Errorf("invalid status: must be 'pending', 'approved', 'rejected', or 'settled'")
	}

	// Update status
	trade.Status = newStatus

	// Store the updated trade
	tradeJSON, err := json.Marshal(trade)
	if err != nil {
		return fmt.Errorf("failed to marshal trade: %v", err)
	}

	err = ctx.GetStub().PutState(tradeID, tradeJSON)
	if err != nil {
		return fmt.Errorf("failed to update trade in ledger: %v", err)
	}

	// If status is "settled", update corresponding orders to "executed"
	if newStatus == "settled" {
		// Update buy order
		buyOrder, err := c.GetOrder(ctx, trade.BuyOrderID)
		if err != nil {
			return fmt.Errorf("failed to get buy order: %v", err)
		}

		if buyOrder.RemainingQty == 0 {
			buyOrder.Status = "executed"
			buyOrder.UpdateTime = time.Now().Format(time.RFC3339)

			buyOrderJSON, err := json.Marshal(buyOrder)
			if err != nil {
				return fmt.Errorf("failed to marshal buy order: %v", err)
			}

			err = ctx.GetStub().PutState(trade.BuyOrderID, buyOrderJSON)
			if err != nil {
				return fmt.Errorf("failed to update buy order: %v", err)
			}
		}

		// Update sell order
		sellOrder, err := c.GetOrder(ctx, trade.SellOrderID)
		if err != nil {
			return fmt.Errorf("failed to get sell order: %v", err)
		}

		if sellOrder.RemainingQty == 0 {
			sellOrder.Status = "executed"
			sellOrder.UpdateTime = time.Now().Format(time.RFC3339)

			sellOrderJSON, err := json.Marshal(sellOrder)
			if err != nil {
				return fmt.Errorf("failed to marshal sell order: %v", err)
			}

			err = ctx.GetStub().PutState(trade.SellOrderID, sellOrderJSON)
			if err != nil {
				return fmt.Errorf("failed to update sell order: %v", err)
			}
		}
	}

	// Emit an event for the trade status update
	err = ctx.GetStub().SetEvent("TradeStatusUpdated", tradeJSON)
	if err != nil {
		return fmt.Errorf("failed to set TradeStatusUpdated event: %v", err)
	}

	return nil
}

// GetOrdersByBroker retrieves all orders for a specific broker
func (c *OrderMatchingContract) GetOrdersByBroker(ctx contractapi.TransactionContextInterface, brokerID string) ([]*Order, error) {
	// Get all orders
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, fmt.Errorf("failed to get all orders: %v", err)
	}
	defer resultsIterator.Close()

	var orders []*Order
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to iterate orders: %v", err)
		}

		// Skip if the key starts with "trade-" (it's a trade, not an order)
		if len(queryResponse.Key) >= 6 && queryResponse.Key[:6] == "trade-" {
			continue
		}

		var order Order
		err = json.Unmarshal(queryResponse.Value, &order)
		if err != nil {
			continue // Skip if not a valid Order
		}

		// Filter by brokerID
		if order.BrokerID == brokerID {
			orders = append(orders, &order)
		}
	}

	return orders, nil
}

// GetTradesByBroker retrieves all trades for a specific broker
func (c *OrderMatchingContract) GetTradesByBroker(ctx contractapi.TransactionContextInterface, brokerID string) ([]*Trade, error) {
	// Get all trades
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, fmt.Errorf("failed to get all trades: %v", err)
	}
	defer resultsIterator.Close()

	var trades []*Trade
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to iterate trades: %v", err)
		}

		// Skip if not a trade (if ID doesn't start with "trade-")
		if len(queryResponse.Key) < 6 || queryResponse.Key[:6] != "trade-" {
			continue
		}

		var trade Trade
		err = json.Unmarshal(queryResponse.Value, &trade)
		if err != nil {
			continue // Skip if not a valid Trade
		}

		// Filter by brokerID (either buy or sell)
		if trade.BuyBrokerID == brokerID || trade.SellBrokerID == brokerID {
			trades = append(trades, &trade)
		}
	}

	return trades, nil
}

// InitiateSettlement creates a settlement instruction for a trade
func (c *OrderMatchingContract) InitiateSettlement(ctx contractapi.TransactionContextInterface, tradeID string) error {
	// This function will create an event that will trigger settlement processing
	// The actual settlement logic will be in the settlement chaincode

	trade, err := c.GetTrade(ctx, tradeID)
	if err != nil {
		return err
	}

	if trade.Status != "pending" {
		return fmt.Errorf("trade %s is not in pending status", tradeID)
	}

	// Create settlement event
	settlementInitiation := struct {
		TradeID      string  `json:"tradeID"`
		BuyBrokerID  string  `json:"buyBrokerID"`
		SellBrokerID string  `json:"sellBrokerID"`
		SecurityID   string  `json:"securityID"`
		Quantity     int     `json:"quantity"`
		Price        float64 `json:"price"`
		InitiatedAt  string  `json:"initiatedAt"`
	}{
		TradeID:      trade.TradeID,
		BuyBrokerID:  trade.BuyBrokerID,
		SellBrokerID: trade.SellBrokerID,
		SecurityID:   trade.SecurityID,
		Quantity:     trade.Quantity,
		Price:        trade.Price,
		InitiatedAt:  time.Now().Format(time.RFC3339),
	}

	settlementJSON, err := json.Marshal(settlementInitiation)
	if err != nil {
		return fmt.Errorf("failed to marshal settlement initiation: %v", err)
	}

	// Emit settlement initiation event
	err = ctx.GetStub().SetEvent("SettlementInitiated", settlementJSON)
	if err != nil {
		return fmt.Errorf("failed to set SettlementInitiated event: %v", err)
	}

	return nil
}

// GetAllSecurities retrieves all securities from the ledger
func (c *OrderMatchingContract) GetAllSecurities(ctx contractapi.TransactionContextInterface) ([]*Security, error) {
	// Get all objects from world state
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, fmt.Errorf("failed to get all securities: %v", err)
	}
	defer resultsIterator.Close()

	var securities []*Security
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to iterate securities: %v", err)
		}

		// Skip if the key starts with "trade-" (it's a trade, not a security)
		if len(queryResponse.Key) >= 6 && queryResponse.Key[:6] == "trade-" {
			continue
		}

		// Try to unmarshal as a Security
		var security Security
		err = json.Unmarshal(queryResponse.Value, &security)
		if err != nil {
			// Not a valid Security, continue to next item
			continue
		}

		// Verify this is a security by checking if required fields exist
		if security.SecurityID != "" && security.Symbol != "" && security.Status != "" {
			securities = append(securities, &security)
		}
	}

	return securities, nil
}

// Helper function to find minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func main() {
	chaincode, err := contractapi.NewChaincode(&OrderMatchingContract{})
	if err != nil {
		fmt.Printf("Error creating order matching chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting order matching chaincode: %s", err.Error())
	}
}
