import sharp from 'sharp'
import { readFileSync, mkdirSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const svgPath   = join(__dirname, 'public', 'favicon.svg')
const publicDir = join(__dirname, 'public')

const svgBuffer = readFileSync(svgPath)

const sizes = [
  { name: 'pwa-64x64.png',   size: 64  },
  { name: 'pwa-192x192.png', size: 192 },
  { name: 'pwa-512x512.png', size: 512 },
  { name: 'apple-touch-icon.png', size: 180 },
  { name: 'maskable-icon-512x512.png', size: 512 },
]

for (const { name, size } of sizes) {
  const out = join(publicDir, name)
  if (name === 'maskable-icon-512x512.png') {
    // Maskable: adiciona padding de 10% (safe zone)
    const inner = Math.round(size * 0.8)
    const pad   = Math.round((size - inner) / 2)
    await sharp(svgBuffer)
      .resize(inner, inner)
      .extend({ top: pad, bottom: pad, left: pad, right: pad, background: '#1f93ff' })
      .png()
      .toFile(out)
  } else {
    await sharp(svgBuffer).resize(size, size).png().toFile(out)
  }
  console.log(`✓ ${name} (${size}x${size})`)
}

console.log('Ícones PWA gerados com sucesso!')
