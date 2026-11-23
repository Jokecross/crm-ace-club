#!/usr/bin/env node
/**
 * Tire au hasard la clé du rapport sans connexion (rapport.html#<clé>).
 *
 *   node scripts/cle-rapport.mjs
 *
 * Écrit la clé dans scripts/rapport-cle.txt (ignoré par git, jamais mis en
 * ligne) et affiche la ligne SQL à passer dans Supabase → SQL Editor. Seule
 * l'empreinte sha256 va dans la base : la clé elle-même n'y est jamais.
 *
 * Relancer le script change la clé : l'ancien lien cesse de marcher dès
 * que la nouvelle ligne SQL est passée.
 */
import fs from 'node:fs'
import crypto from 'node:crypto'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const ICI = path.dirname(fileURLToPath(import.meta.url))
const fichier = path.join(ICI, 'rapport-cle.txt')

const cle = crypto.randomBytes(24).toString('base64url')   // 32 caractères, 192 bits
const empreinte = crypto.createHash('sha256').update(cle).digest('hex')

fs.writeFileSync(fichier, cle + '\n', { mode: 0o600 })

console.log(`Clé écrite dans ${fichier}\n`)
console.log('1. Dans Supabase → SQL Editor, passe :\n')
console.log(`insert into public.cles_integration (nom, empreinte)
values ('rapport', '${empreinte}')
on conflict (nom) do update set empreinte = excluded.empreinte, created_at = now();\n`)
console.log('2. Le lien du rapport (à ne donner qu\'aux personnes concernées) :\n')
console.log(`   https://<adresse du CRM>/rapport.html#${cle}\n`)
