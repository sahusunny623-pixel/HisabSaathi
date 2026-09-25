export function calculateInvoice(items, paidMinor = 0) {
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error('At least one item is required');
  }

  const normalized = items.map((item, index) => {
    const quantity = Number(item.quantity);
    const unitPriceMinor = Number(item.unitPriceMinor);
    if (!Number.isFinite(quantity) || quantity <= 0) {
      throw new Error(`Item ${index + 1} quantity must be greater than zero`);
    }
    if (!Number.isInteger(unitPriceMinor) || unitPriceMinor < 0) {
      throw new Error(`Item ${index + 1} price is invalid`);
    }
    const amountMinor = Math.round(quantity * unitPriceMinor);
    return { ...item, quantity, unitPriceMinor, amountMinor };
  });

  const subtotalMinor = normalized.reduce((total, item) => total + item.amountMinor, 0);
  if (!Number.isInteger(paidMinor) || paidMinor < 0) {
    throw new Error('Paid amount is invalid');
  }
  if (paidMinor > subtotalMinor) {
    return {
      subtotalMinor,
      paidMinor,
      creditMinor: 0,
      advanceMinor: paidMinor - subtotalMinor,
      items: normalized,
    };
  }
  return {
    subtotalMinor,
    paidMinor,
    creditMinor: subtotalMinor - paidMinor,
    advanceMinor: 0,
    items: normalized,
  };
}

export function applyLedgerBalance(entries) {
  return entries.reduce((balance, entry) => balance + Number(entry.amountMinor), 0);
}