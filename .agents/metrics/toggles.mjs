export const toggleScript = `
for (const figure of document.querySelectorAll('figure.chart')) {
  const keys = [...figure.querySelectorAll('.key')]
  const pressed = () => keys.filter((key) => key.getAttribute('aria-pressed') === 'true')
  for (const key of keys) {
    key.addEventListener('click', () => {
      const on = key.getAttribute('aria-pressed') === 'true'
      if (on && pressed().length === 1) return
      key.setAttribute('aria-pressed', String(!on))
      const shown = pressed().map((item) => item.dataset.series)
      for (const part of figure.querySelectorAll('[data-shown]')) part.hidden = part.dataset.shown !== shown.join(',')
      const top = Number(figure.querySelector('.y:not([hidden])').dataset.top)
      for (const bar of figure.querySelectorAll('.bar')) {
        bar.parentElement.hidden = !shown.includes(bar.dataset.series)
        bar.style.height = (bar.dataset.value / top) * 100 + '%'
      }
    })
  }
}
`
