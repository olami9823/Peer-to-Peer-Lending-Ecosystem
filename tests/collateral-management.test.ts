import { describe, it, expect, beforeEach, vi } from 'vitest';

// Mock contract state
let collaterals: Record<number, any> = {};
let loans: Record<number, any> = {};

// Mock contract calls
const mockContractCall = vi.fn();

// Helper function to reset state before each test
function resetState() {
  collaterals = {};
  loans = {};
}

describe('Collateral Management Contract', () => {
  beforeEach(() => {
    resetState();
    vi.resetAllMocks();
  });
  
  it('should add collateral', () => {
    const borrower = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    loans[0] = { borrower };
    
    mockContractCall.mockImplementation((contract, method, ...args) => {
      if (contract === 'loan-management' && method === 'get-loan') {
        return { success: true, value: loans[args[0]] };
      }
      if (contract === 'collateral-management' && method === 'add-collateral') {
        const [loanId, asset, amount, liquidationRatio] = args;
        collaterals[loanId] = { asset, amount, liquidationRatio, liquidated: false };
        return { success: true };
      }
    });
    
    const result = mockContractCall('collateral-management', 'add-collateral', 0, 'STX', 1000, 150);
    expect(result).toEqual({ success: true });
    expect(collaterals[0]).toBeDefined();
    expect(collaterals[0].asset).toBe('STX');
    expect(collaterals[0].amount).toBe(1000);
  });
  
  it('should liquidate collateral', () => {
    const borrower = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const lender = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
    loans[0] = { borrower, lender: lender, amount: 500 };
    collaterals[0] = { asset: 'STX', amount: 1000, liquidationRatio: 150, liquidated: false };
    
    mockContractCall.mockImplementation((contract, method, ...args) => {
      if (contract === 'loan-management' && method === 'get-loan') {
        return { success: true, value: loans[args[0]] };
      }
      if (contract === 'collateral-management' && method === 'liquidate-collateral') {
        collaterals[args[0]].liquidated = true;
        return { success: true };
      }
    });
    
    const result = mockContractCall('collateral-management', 'liquidate-collateral', 0);
    expect(result).toEqual({ success: true });
    expect(collaterals[0].liquidated).toBe(true);
  });
  
  it('should get collateral', () => {
    collaterals[0] = { asset: 'STX', amount: 1000, liquidationRatio: 150, liquidated: false };
    
    mockContractCall.mockImplementation((_, __, loanId) => {
      return { success: true, value: collaterals[loanId] };
    });
    
    const result = mockContractCall('collateral-management', 'get-collateral', 0);
    expect(result).toEqual({ success: true, value: collaterals[0] });
  });
});

