import { readFile, writeFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

const packageFile = fileURLToPath(
  new URL('../ios/App/CapApp-SPM/Package.swift', import.meta.url),
)

const pluginPaths = new Map([
  ['CapacitorApp', '../../../node_modules/@capacitor/app'],
  ['CapacitorDevice', '../../../node_modules/@capacitor/device'],
  ['CapacitorFilesystem', '../../../node_modules/@capacitor/filesystem'],
  ['CapacitorShare', '../../../node_modules/@capacitor/share'],
])

let source = await readFile(packageFile, 'utf8')
for (const [name, path] of pluginPaths) {
  const pattern = new RegExp(
    `(\\.package\\(name: "${name}", path: ")[^"]+("\\))`,
  )
  if (!pattern.test(source)) {
    throw new Error(`Missing ${name} package declaration in ${packageFile}`)
  }
  source = source.replace(pattern, `$1${path}$2`)
}

await writeFile(packageFile, source)
