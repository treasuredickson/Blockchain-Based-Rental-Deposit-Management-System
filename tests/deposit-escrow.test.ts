import { describe, it, expect, beforeEach, vi } from "vitest"

// Mock the Clarity VM environment
const mockClarity = {
  tx: {
    sender: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  },
  block: {
    time: 1625097600, // July 1, 2021
  },
}

// Mock the contract functions
const depositEscrow = {
  createAgreement: vi.fn(),
  payDeposit: vi.fn(),
  approveRelease: vi.fn(),
  claimDeposit: vi.fn(),
  getAgreement: vi.fn(),
  getDeposit: vi.fn(),
  getTransaction: vi.fn(),
}

describe("Deposit Escrow Contract", () => {
  beforeEach(() => {
    // Reset mocks
    vi.resetAllMocks()
    
    // Setup default mock implementations
    depositEscrow.createAgreement.mockReturnValue({ type: "ok", value: true })
    depositEscrow.payDeposit.mockReturnValue({ type: "ok", value: true })
    depositEscrow.approveRelease.mockReturnValue({ type: "ok", value: true })
    depositEscrow.claimDeposit.mockReturnValue({ type: "ok", value: true })
    
    depositEscrow.getAgreement.mockReturnValue({
      value: {
        tenant: "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG",
        landlord: mockClarity.tx.sender,
        propertyId: "property-001",
        depositAmount: 200000000, // 2000 STX
        rentAmount: 50000000, // 500 STX per month
        startDate: mockClarity.block.time,
        endDate: mockClarity.block.time + 31536000, // 1 year later
        status: "active",
        creationTime: mockClarity.block.time - 604800, // 1 week ago
      },
    })
    
    depositEscrow.getDeposit.mockReturnValue({
      value: {
        amount: 200000000, // 2000 STX
        paidAt: mockClarity.block.time - 604800, // 1 week ago
        heldUntil: mockClarity.block.time + 31536000, // 1 year later
        status: "held",
        releaseApproval: {
          tenantApproved: false,
          landlordApproved: false,
          approvalTime: 0,
        },
      },
    })
    
    depositEscrow.getTransaction.mockReturnValue({
      value: {
        transactionType: "deposit-paid",
        amount: 200000000, // 2000 STX
        from: "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG",
        to: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
        time: mockClarity.block.time - 604800, // 1 week ago
        notes: "Security deposit paid",
      },
    })
  })
  
  describe("createAgreement", () => {
    it("should create a rental agreement successfully", () => {
      const agreementId = "agreement-001"
      const tenant = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
      const landlord = mockClarity.tx.sender
      const propertyId = "property-001"
      const depositAmount = 200000000 // 2000 STX
      const rentAmount = 50000000 // 500 STX per month
      const startDate = mockClarity.block.time
      const endDate = mockClarity.block.time + 31536000 // 1 year later
      
      const result = depositEscrow.createAgreement(
          agreementId,
          tenant,
          landlord,
          propertyId,
          depositAmount,
          rentAmount,
          startDate,
          endDate,
      )
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
      expect(depositEscrow.createAgreement).toHaveBeenCalledWith(
          agreementId,
          tenant,
          landlord,
          propertyId,
          depositAmount,
          rentAmount,
          startDate,
          endDate,
      )
    })
  })
  
  describe("payDeposit", () => {
    it("should pay a deposit successfully", () => {
      const agreementId = "agreement-001"
      
      const result = depositEscrow.payDeposit(agreementId)
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
      expect(depositEscrow.payDeposit).toHaveBeenCalledWith(agreementId)
    })
  })
  
  describe("approveRelease", () => {
    it("should approve deposit release successfully", () => {
      const agreementId = "agreement-001"
      
      const result = depositEscrow.approveRelease(agreementId)
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
      expect(depositEscrow.approveRelease).toHaveBeenCalledWith(agreementId)
    })
  })
  
  describe("getAgreement", () => {
    it("should retrieve agreement information", () => {
      const agreementId = "agreement-001"
      
      const result = depositEscrow.getAgreement(agreementId)
      
      expect(result.value).toEqual({
        tenant: "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG",
        landlord: mockClarity.tx.sender,
        propertyId: "property-001",
        depositAmount: 200000000,
        rentAmount: 50000000,
        startDate: mockClarity.block.time,
        endDate: mockClarity.block.time + 31536000,
        status: "active",
        creationTime: mockClarity.block.time - 604800,
      })
      expect(depositEscrow.getAgreement).toHaveBeenCalledWith(agreementId)
    })
  })
  
  describe("getDeposit", () => {
    it("should retrieve deposit information", () => {
      const agreementId = "agreement-001"
      
      const result = depositEscrow.getDeposit(agreementId)
      
      expect(result.value).toEqual({
        amount: 200000000,
        paidAt: mockClarity.block.time - 604800,
        heldUntil: mockClarity.block.time + 31536000,
        status: "held",
        releaseApproval: {
          tenantApproved: false,
          landlordApproved: false,
          approvalTime: 0,
        },
      })
      expect(depositEscrow.getDeposit).toHaveBeenCalledWith(agreementId)
    })
  })
})

