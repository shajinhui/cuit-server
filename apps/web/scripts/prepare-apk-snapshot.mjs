import { cp, mkdir, readdir, rm, stat } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const projectRoot = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const snapshotDir = path.join(projectRoot, 'reference', 'apk-0.1.0-public')
const outputDir = path.join(projectRoot, 'dist')

const snapshotFiles = await readdir(snapshotDir)
if (!snapshotFiles.includes('index.html')) {
  throw new Error(`APK snapshot is incomplete: ${snapshotDir}/index.html is missing`)
}

await rm(outputDir, { force: true, recursive: true })
await mkdir(outputDir, { recursive: true })
await cp(snapshotDir, outputDir, { recursive: true })

const indexStats = await stat(path.join(outputDir, 'index.html'))
console.log(`Prepared APK 0.1.0 web snapshot in dist (${indexStats.size} byte index.html)`)
