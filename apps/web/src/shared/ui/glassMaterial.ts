/** Material presets only. Native controls own focus, clicks and gestures. */
export const glassMaterials = {
  navigation: { displacementScale: 18, blurAmount: 0.3, saturation: 135, aberrationIntensity: 0.5, fallbackBlur: 14, fill: 'var(--bg-glass-faint)' },
  selection: { displacementScale: 14, blurAmount: 0.125, saturation: 145, aberrationIntensity: 0.5, fallbackBlur: 8, fill: 'var(--control-track-soft)' },
  control: { displacementScale: 14, blurAmount: 0.15, saturation: 125, aberrationIntensity: 0.35, fallbackBlur: 12, fill: 'var(--control-track-soft)' },
  popover: { displacementScale: 16, blurAmount: 0.4, saturation: 140, aberrationIntensity: 0.4, fallbackBlur: 24, fill: 'var(--bg-glass)' },
  toolbar: { displacementScale: 18, blurAmount: 0.3, saturation: 140, aberrationIntensity: 0.5, fallbackBlur: 18, fill: 'var(--bg-glass-faint)' },
  icon: { displacementScale: 10, blurAmount: 0.15, saturation: 135, aberrationIntensity: 0.3, fallbackBlur: 12, fill: 'var(--bg-glass-faint)' },
} as const

export type GlassMaterial = keyof typeof glassMaterials
