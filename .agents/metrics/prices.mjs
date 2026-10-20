import { loadCached } from './cache.mjs'

export const priceUrl = 'https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json'

const anthropicRates = (text) => {
  const rates = {}
  for (const [id, entry] of Object.entries(JSON.parse(text))) {
    if (entry?.litellm_provider !== 'anthropic') continue
    rates[id] = {
      input: entry.input_cost_per_token,
      output: entry.output_cost_per_token,
      cache_read: entry.cache_read_input_token_cost,
      cache_write: entry.cache_creation_input_token_cost,
    }
  }
  if (Object.keys(rates).length === 0) throw new Error('the price source has no Anthropic prices')
  return rates
}

export const loadPrices = (file) => loadCached(file, process.env.AI_FOR_DUMMIES_PRICES_URL ?? priceUrl, anthropicRates)

export const ratesFor = (prices, id) => prices[id] ?? prices[id.replace(/-\d{8}$/, '')] ?? null
