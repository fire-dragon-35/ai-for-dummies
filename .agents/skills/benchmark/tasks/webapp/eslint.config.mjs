export default [
  {
    languageOptions: { ecmaVersion: 'latest', sourceType: 'module' },
    rules: {
      eqeqeq: 'error',
      'no-unused-vars': 'error',
      'no-unreachable': 'error',
      'no-dupe-keys': 'error',
      'no-empty': 'error',
      'no-fallthrough': 'error',
      'no-self-compare': 'error',
      'no-var': 'error',
      'prefer-const': 'error',
      'no-duplicate-imports': 'error',
      complexity: ['warn', 15],
      'max-depth': ['warn', 4],
      'max-params': ['warn', 5],
      'max-lines-per-function': ['warn', 80],
    },
  },
  { files: ['**/*.cjs'], languageOptions: { sourceType: 'commonjs' } },
]
