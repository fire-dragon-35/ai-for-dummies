import { loadCached } from './cache.mjs'

const modelsUrl = 'https://raw.githubusercontent.com/mlco2/ecologits/main/ecologits/data/models.json'

const batch = 64
const quantizationBits = 16
const gpuMemory = 80
const serverGpus = 8
const serverKilowatts = 1.2
const gpuEnergy = { alpha: 1.1665273170451914e-6, beta: -0.011205921025579175, gamma: 4.052928146734005e-5 }
const pue = 1.09

const parseModels = (text) => {
  const { models, aliases } = JSON.parse(text)
  const anthropic = models.filter((model) => model.provider === 'anthropic' && model.deployment?.tps)
  if (anthropic.length === 0) throw new Error('the model data has no Anthropic models')
  return {
    models: Object.fromEntries(anthropic.map((model) => [model.name, { architecture: model.architecture, deployment: model.deployment }])),
    aliases: Object.fromEntries(aliases.filter((alias) => alias.provider === 'anthropic').map((alias) => [alias.name, alias.alias])),
  }
}

export const loadModels = (file) => loadCached(file, process.env.AI_FOR_DUMMIES_MODELS_URL ?? modelsUrl, parseModels)

export const modelFor = (data, id) => {
  const name = data.aliases[id] ?? id
  return data.models[name] ?? data.models[name.replace(/-\d{8}$/, '')] ?? null
}

const parametersAt = ({ architecture }) =>
  architecture.type === 'moe'
    ? { active: architecture.parameters.active.min, total: architecture.parameters.total }
    : { active: architecture.parameters.min, total: architecture.parameters.min }

export const outputEnergy = (model, outputTokens) => {
  if (outputTokens <= 0) return 0
  const { active, total } = parametersAt(model)
  const gpus = 2 ** Math.ceil(Math.log2(Math.ceil((1.2 * total * quantizationBits) / 8 / gpuMemory)))
  const perToken = (gpuEnergy.alpha * Math.exp(gpuEnergy.beta * batch) * active + gpuEnergy.gamma) / 1000
  const seconds = model.deployment.ttft + outputTokens / model.deployment.tps
  const server = (seconds / 3600) * serverKilowatts * (gpus / serverGpus) * (1 / batch)
  return pue * (server + gpus * outputTokens * perToken) * 1000
}
