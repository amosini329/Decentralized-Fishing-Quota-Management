import { describe, it, expect, beforeEach, vi } from 'vitest';

// Mock the Clarity contract interactions

const mockSpecies = new Map();
const mockVesselQuotas = new Map();
let mockAdmin = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'; // Example principal
let mockTxSender = mockAdmin;

// Helper function to create a composite key for vessel quotas
const createVesselQuotaKey = (vesselId, speciesId) => `${vesselId}-${speciesId}`;

// Mock contract functions
const mockContractFunctions = {
  'set-species': (speciesId, name, totalQuota, seasonStart, seasonEnd) => {
    if (mockTxSender !== mockAdmin) {
      return { type: 'err', value: 1 };
    }
    
    mockSpecies.set(speciesId, {
      name,
      'total-quota': totalQuota,
      'allocated-quota': 0,
      'season-start': seasonStart,
      'season-end': seasonEnd
    });
    
    return { type: 'ok', value: true };
  },
  
  'allocate-quota': (vesselId, speciesId, amount) => {
    if (mockTxSender !== mockAdmin) {
      return { type: 'err', value: 1 };
    }
    
    if (!mockSpecies.has(speciesId)) {
      return { type: 'err', value: 2 };
    }
    
    const species = mockSpecies.get(speciesId);
    const currentAllocated = species['allocated-quota'];
    const totalQuota = species['total-quota'];
    
    if (currentAllocated + amount > totalQuota) {
      return { type: 'err', value: 3 };
    }
    
    // Update species allocated quota
    mockSpecies.set(speciesId, {
      ...species,
      'allocated-quota': currentAllocated + amount
    });
    
    // Set vessel quota
    const key = createVesselQuotaKey(vesselId, speciesId);
    mockVesselQuotas.set(key, {
      'allocated-amount': amount,
      'remaining-amount': amount,
      'allocation-date': Date.now()
    });
    
    return { type: 'ok', value: true };
  },
  
  'get-species-info': (speciesId) => {
    if (!mockSpecies.has(speciesId)) {
      return null;
    }
    return mockSpecies.get(speciesId);
  },
  
  'get-vessel-quota': (vesselId, speciesId) => {
    const key = createVesselQuotaKey(vesselId, speciesId);
    if (!mockVesselQuotas.has(key)) {
      return null;
    }
    return mockVesselQuotas.get(key);
  },
  
  'update-remaining-quota': (vesselId, speciesId, catchAmount) => {
    const key = createVesselQuotaKey(vesselId, speciesId);
    if (!mockVesselQuotas.has(key)) {
      return { type: 'err', value: 2 };
    }
    
    const quota = mockVesselQuotas.get(key);
    const remaining = quota['remaining-amount'];
    
    if (catchAmount > remaining) {
      return { type: 'err', value: 5 };
    }
    
    mockVesselQuotas.set(key, {
      ...quota,
      'remaining-amount': remaining - catchAmount
    });
    
    return { type: 'ok', value: true };
  }
};

describe('Quota Allocation Contract', () => {
  beforeEach(() => {
    mockSpecies.clear();
    mockVesselQuotas.clear();
    mockTxSender = mockAdmin;
  });
  
  it('should add a new species', () => {
    const result = mockContractFunctions['set-species']('COD', 'Atlantic Cod', 100000, 1609459200, 1640995200);
    expect(result.type).toBe('ok');
    
    const species = mockContractFunctions['get-species-info']('COD');
    expect(species).not.toBeNull();
    expect(species.name).toBe('Atlantic Cod');
    expect(species['total-quota']).toBe(100000);
    expect(species['allocated-quota']).toBe(0);
  });
  
  it('should not add a species if not admin', () => {
    mockTxSender = 'ST2PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    
    const result = mockContractFunctions['set-species']('COD', 'Atlantic Cod', 100000, 1609459200, 1640995200);
    expect(result.type).toBe('err');
    expect(result.value).toBe(1);
  });
  
  it('should allocate quota to a vessel', () => {
    mockContractFunctions['set-species']('COD', 'Atlantic Cod', 100000, 1609459200, 1640995200);
    
    const result = mockContractFunctions['allocate-quota']('VESSEL001', 'COD', 5000);
    expect(result.type).toBe('ok');
    
    const species = mockContractFunctions['get-species-info']('COD');
    expect(species['allocated-quota']).toBe(5000);
    
    const vesselQuota = mockContractFunctions['get-vessel-quota']('VESSEL001', 'COD');
    expect(vesselQuota).not.toBeNull();
    expect(vesselQuota['allocated-amount']).toBe(5000);
    expect(vesselQuota['remaining-amount']).toBe(5000);
  });
  
  it('should not allocate quota exceeding total quota', () => {
    mockContractFunctions['set-species']('COD', 'Atlantic Cod', 100000, 1609459200, 1640995200);
    mockContractFunctions['allocate-quota']('VESSEL001', 'COD', 80000);
    
    const result = mockContractFunctions['allocate-quota']('VESSEL002', 'COD', 30000);
    expect(result.type).toBe('err');
    expect(result.value).toBe(3);
    
    // Verify allocated quota wasn't changed
    const species = mockContractFunctions['get-species-info']('COD');
    expect(species['allocated-quota']).toBe(80000);
  });
  
  it('should update remaining quota when catch is reported', () => {
    mockContractFunctions['set-species']('COD', 'Atlantic Cod', 100000, 1609459200, 1640995200);
    mockContractFunctions['allocate-quota']('VESSEL001', 'COD', 5000);
    
    const result = mockContractFunctions['update-remaining-quota']('VESSEL001', 'COD', 2000);
    expect(result.type).toBe('ok');
    
    const vesselQuota = mockContractFunctions['get-vessel-quota']('VESSEL001', 'COD');
    expect(vesselQuota['remaining-amount']).toBe(3000);
  });
  
  it('should not allow catch exceeding remaining quota', () => {
    mockContractFunctions['set-species']('COD', 'Atlantic Cod', 100000, 1609459200, 1640995200);
    mockContractFunctions['allocate-quota']('VESSEL001', 'COD', 5000);
    
    const result = mockContractFunctions['update-remaining-quota']('VESSEL001', 'COD', 6000);
    expect(result.type).toBe('err');
    expect(result.value).toBe(5);
    
    // Verify remaining quota wasn't changed
    const vesselQuota = mockContractFunctions['get-vessel-quota']('VESSEL001', 'COD');
    expect(vesselQuota['remaining-amount']).toBe(5000);
  });
});
