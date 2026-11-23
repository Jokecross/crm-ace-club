#!/usr/bin/env node
/**
 * Crée le premier compte admin, puis les comptes des setters, et les
 * rattache à l'équipe (Base44, clé `starter`, la seule équipe d'ACE Club).
 *
 *   SUPABASE_URL="https://xxxx.supabase.co" SUPABASE_SERVICE_ROLE_KEY="…" node scripts/creer-comptes.mjs
 *
 * Le script lit scripts/equipe.json, crée un utilisateur par ligne avec un
 * mot de passe tiré au hasard (20 caractères, rien à voir avec le prénom),
 * l'inscrit dans la table `staff` avec son rôle, puis écrit
 * scripts/comptes.csv — le seul endroit où les mots de passe apparaissent
 * (ignoré par git, jamais mis en ligne). Ce fichier reste sur ta machine : distribue-le, puis
 * supprime-le.
 *
 * Relançable : un compte déjà créé est retrouvé, pas dupliqué, et son mot
 * de passe n'est pas réinitialisé.
 */
import fs from 'node:fs'
import crypto from 'node:crypto'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const ICI = path.dirname(fileURLToPath(import.meta.url))
const URL_SUPABASE = process.env.SUPABASE_URL   // obligatoire : jamais de projet par défaut
const CLE = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!URL_SUPABASE) {
  console.error("Il manque l'URL du projet : SUPABASE_URL=\"https://xxxx.supabase.co\" node scripts/creer-comptes.mjs")
  process.exit(1)
}
if (!CLE) {
  console.error(
    "Il manque la clé service_role.\n" +
    "Supabase → Project Settings → API → service_role, puis :\n\n" +
    '  SUPABASE_SERVICE_ROLE_KEY="…" node scripts/creer-comptes.mjs\n'
  )
  process.exit(1)
}

const equipe = JSON.parse(fs.readFileSync(path.join(ICI, 'equipe.json'), 'utf8'))

const api = async (chemin, options = {}) => {
  const r = await fetch(`${URL_SUPABASE}${chemin}`, {
    ...options,
    headers: {
      apikey: CLE,
      Authorization: `Bearer ${CLE}`,
      'Content-Type': 'application/json',
      ...options.headers,
    },
  })
  const texte = await r.text()
  const corps = texte ? JSON.parse(texte) : null
  if (!r.ok) throw new Error(corps?.msg || corps?.message || texte || r.status)
  return corps
}

/* Le mot de passe : 20 caractères tirés au hasard (lettres et chiffres,
   sans les signes ambigus 0/O, 1/l/I), soit plus de 110 bits. Jamais dérivé
   du prénom ni de l'adresse : la base contient les coordonnées de tous les
   leads. Chacun peut le changer ensuite depuis l'écran de connexion. */
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
const motDePassePour = () => {
  let mdp = ''
  while (mdp.length < 20) {
    const octet = crypto.randomBytes(1)[0]
    // Rejet des valeurs hors multiple de la taille de l'alphabet : pas de biais.
    if (octet < 256 - (256 % ALPHABET.length)) mdp += ALPHABET[octet % ALPHABET.length]
  }
  return mdp
}

/* Un compte peut déjà exister : on le retrouve plutôt que d'échouer. */
async function trouverExistant(email) {
  for (let page = 1; page <= 20; page++) {
    const { users } = await api(`/auth/v1/admin/users?page=${page}&per_page=200`)
    const trouve = users.find((u) => u.email?.toLowerCase() === email.toLowerCase())
    if (trouve) return trouve
    if (users.length < 200) return null
  }
  return null
}

/* Avec REINIT=1, les comptes déjà créés reçoivent un nouveau mot de passe.
   Sans ce drapeau, ils sont laissés tels quels. */
const REINIT = process.env.REINIT === '1'

const lignes = []
let crees = 0
let reinities = 0
let existants = 0

for (const { prenom, email, role = 'setter', equipe: equipeDe = 'starter', equipes } of equipe) {
  if (!email || /A-FOURNIR|\[À FOURNIR/i.test(email) || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    console.error(`✗  ${String(prenom).padEnd(10)} adresse à renseigner dans scripts/equipe.json : ${email}`)
    continue
  }
  if (!['admin', 'setter'].includes(role)) {
    console.error(`✗  ${String(prenom).padEnd(10)} rôle inconnu « ${role} » (admin ou setter)`)
    continue
  }
  try {
    let utilisateur = await trouverExistant(email)
    let mdp = null

    if (utilisateur && REINIT) {
      // Le mot de passe d'origine ne se relit pas : pour le retrouver, il
      // faut en poser un nouveau.
      mdp = motDePassePour()
      await api(`/auth/v1/admin/users/${utilisateur.id}`, {
        method: 'PUT',
        body: JSON.stringify({ password: mdp }),
      })
      reinities++
      console.log(`↻  ${prenom.padEnd(10)} ${email.padEnd(28)} ${role.padEnd(6)} réinitialisé`)
    } else if (utilisateur) {
      existants++
      console.log(`   ${prenom.padEnd(10)} ${email.padEnd(28)} ${role.padEnd(6)} déjà présent`)
    } else {
      mdp = motDePassePour()
      // L'API renvoie l'utilisateur directement, sans enveloppe « user ».
      utilisateur = await api('/auth/v1/admin/users', {
        method: 'POST',
        body: JSON.stringify({ email, password: mdp, email_confirm: true }),
      })
      crees++
      console.log(`✓  ${prenom.padEnd(10)} ${email.padEnd(28)} ${role.padEnd(6)} ${equipeDe.padEnd(14)} créé`)
    }

    await api('/rest/v1/staff', {
      method: 'POST',
      headers: { Prefer: 'resolution=merge-duplicates' },
      body: JSON.stringify({
        user_id: utilisateur.id,
        first_name: prenom,
        role,
        equipe: equipeDe,
        // Les équipes accessibles ; à défaut, la principale seule.
        equipes: equipes && equipes.length ? equipes : [equipeDe],
        actif: true,
      }),
    })

    lignes.push([prenom, email, role, mdp || '(mot de passe inchangé)'])
  } catch (e) {
    console.error(`✗  ${prenom.padEnd(10)} ${email.padEnd(28)} ${e.message}`)
  }
}

// On n'écrase le fichier que s'il contient de nouveaux mots de passe :
// relancer le script après coup effacerait ceux du premier passage.
const csv = path.join(ICI, 'comptes.csv')
if (crees + reinities > 0) {
  fs.writeFileSync(
    csv,
    'Prénom,E-mail,Rôle,Mot de passe\n' +
      lignes.map((l) => l.map((c) => `"${c}"`).join(',')).join('\n') +
      '\n',
    { mode: 0o600 }
  )
}

console.log(
  `\n${crees} créé(s), ${reinities} réinitialisé(s), ${existants} inchangé(s).` +
  (crees + reinities > 0
    ? `\nMots de passe dans ${csv}\nDistribue-les, puis supprime le fichier : rm "${csv}"\n`
    : `\nAucun nouveau mot de passe. Pour en reposer : REINIT=1 ...\n`)
)
