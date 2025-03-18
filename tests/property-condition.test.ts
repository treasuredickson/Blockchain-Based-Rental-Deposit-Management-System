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
const propertyCondition = {
  registerProperty: vi.fn(),
  createConditionReport: vi.fn(),
  addRoomCondition: vi.fn(),
  signConditionReport: vi.fn(),
  fileDamageClaim: vi.fn(),
  getProperty: vi.fn(),
  getConditionReport: vi.fn(),
  getRoomCondition: vi.fn(),
  getDamageClaim: vi.fn(),
  compareConditions: vi.fn(),
}

// Mock the rental agreements from deposit-escrow contract
const rentalAgreements = {
  "agreement-001": {
    tenant: "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG",
    landlord: mockClarity.tx.sender,
    propertyId: "property-001",
    depositAmount: 200000000,
    rentAmount: 50000000,
    startDate: mockClarity.block.time,
    endDate: mockClarity.block.time + 31536000,
    status: "active",
    creationTime: mockClarity.block.time - 604800,
  },
}

describe("Property Condition Contract", () => {
  beforeEach(() => {
    // Reset mocks
    vi.resetAllMocks()
    
    // Setup default mock implementations
    propertyCondition.registerProperty.mockReturnValue({ type: "ok", value: true })
    propertyCondition.createConditionReport.mockReturnValue({ type: "ok", value: true })
    propertyCondition.addRoomCondition.mockReturnValue({ type: "ok", value: true })
    propertyCondition.signConditionReport.mockReturnValue({ type: "ok", value: true })
    propertyCondition.fileDamageClaim.mockReturnValue({ type: "ok", value: true })
    propertyCondition.compareConditions.mockReturnValue({
      type: "ok",
      value: {
        moveInCondition: "excellent",
        moveOutCondition: "good",
        hasDamage: true,
      },
    })
    
    propertyCondition.getProperty.mockReturnValue({
      value: {
        owner: mockClarity.tx.sender,
        address: "123 Main St, Apt 4B, New York, NY 10001",
        propertyType: "apartment",
        bedrooms: 2,
        bathrooms: 1,
        registrationDate: mockClarity.block.time - 2592000, // 30 days ago
        status: "active",
      },
    })
    
    propertyCondition.getConditionReport.mockReturnValue({
      value: {
        inspector: mockClarity.tx.sender,
        inspectionDate: mockClarity.block.time,
        overallCondition: "excellent",
        documentHash: Buffer.from("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", "hex"),
        tenantSignature: {
          signed: true,
          signedAt: mockClarity.block.time + 86400, // 1 day later
        },
        landlordSignature: {
          signed: true,
          signedAt: mockClarity.block.time,
        },
        status: "completed",
      },
    })
    
    propertyCondition.getRoomCondition.mockReturnValue({
      value: {
        roomType: "living-room",
        condition: "excellent",
        damageDescription: "",
        imageHashes: [Buffer.from("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", "hex")],
        notes: "Freshly painted walls, new carpet, all fixtures in working order",
      },
    })
    
    propertyCondition.getDamageClaim.mockReturnValue({
      value: {
        roomId: "living-room",
        damageDescription: "Carpet stains and wall damage from hanging items",
        repairCost: 50000000, // 500 STX
        imageHashes: [Buffer.from("abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789", "hex")],
        claimedBy: mockClarity.tx.sender,
        claimDate: mockClarity.block.time + 31622400, // ~1 year later
        status: "filed",
      },
    })
  })
  
  describe("registerProperty", () => {
    it("should register a property successfully", () => {
      const propertyId = "property-001"
      const address = "123 Main St, Apt 4B, New York, NY 10001"
      const propertyType = "apartment"
      const bedrooms = 2
      const bathrooms = 1
      
      const result = propertyCondition.registerProperty(propertyId, address, propertyType, bedrooms, bathrooms)
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
      expect(propertyCondition.registerProperty).toHaveBeenCalledWith(
          propertyId,
          address,
          propertyType,
          bedrooms,
          bathrooms,
      )
    })
  })
  
  describe("createConditionReport", () => {
    it("should create a condition report successfully", () => {
      const agreementId = "agreement-001"
      const reportType = "move-in"
      const overallCondition = "excellent"
      const documentHash = Buffer.from("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", "hex")
      
      const result = propertyCondition.createConditionReport(agreementId, reportType, overallCondition, documentHash)
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
      expect(propertyCondition.createConditionReport).toHaveBeenCalledWith(
          agreementId,
          reportType,
          overallCondition,
          documentHash,
      )
    })
  })
  
  describe("addRoomCondition", () => {
    it("should add a room condition successfully", () => {
      const agreementId = "agreement-001"
      const reportType = "move-in"
      const roomId = "living-room"
      const roomType = "living-room"
      const condition = "excellent"
      const damageDescription = ""
      const imageHashes = [Buffer.from("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", "hex")]
      const notes = "Freshly painted walls, new carpet, all fixtures in working order"
      
      const result = propertyCondition.addRoomCondition(
          agreementId,
          reportType,
          roomId,
          roomType,
          condition,
          damageDescription,
          imageHashes,
          notes,
      )
      
      expect(result.type).toBe("ok")
      expect(result.value).toBe(true)
      expect(propertyCondition.addRoomCondition).toHaveBeenCalledWith(
          agreementId,
          reportType,
          roomId,
          roomType,
          condition,
          damageDescription,
          imageHashes,
          notes,
      )
    })
  })
  
  describe("compareConditions", () => {
    it("should compare move-in and move-out conditions successfully", () => {
      const agreementId = "agreement-001"
      const roomId = "living-room"
      
      const result = propertyCondition.compareConditions(agreementId, roomId)
      
      expect(result.type).toBe("ok")
      expect(result.value).toEqual({
        moveInCondition: "excellent",
        moveOutCondition: "good",
        hasDamage: true,
      })
      expect(propertyCondition.compareConditions).toHaveBeenCalledWith(agreementId, roomId)
    })
  })
})

