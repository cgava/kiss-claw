# Architecture

Pourquoi kiss-claw utilise 4 agents specialises et comment leur separation des responsabilites ameliore la qualite du travail.

## Pourquoi 4 agents et pas 1 ?

Un agent unique qui planifie, implemente, revoit et ameliore son propre travail souffre de plusieurs biais :

- **Biais de confirmation** : un agent qui revoit son propre code a tendance a valider ses propres choix. Il ne voit pas les erreurs qu'il a commises parce qu'il a fait les memes hypotheses en codant et en reviewant.
- **Derive de scope** : un agent polyvalent a tendance a deborder de son mandat. Il corrige des choses qu'on ne lui a pas demandees, ou il planifie tout seul sans validation.
- **Perte de contexte** : un agent unique accumule du contexte de planification, d'implementation et de review dans la meme fenetre. Les informations se melangent et la qualite se degrade.

La separation en 4 agents force une discipline :

| Agent            | Fait                          | Ne fait PAS                    |
|------------------|-------------------------------|-------------------------------|
| kiss-orchestrator | Planifie, coordonne           | Implemente, revoit            |
| kiss-executor     | Implemente                    | Planifie, revoit              |
| kiss-verificator  | Revoit les sorties executor   | Modifie le code, planifie     |
| kiss-improver     | Analyse et propose            | Applique sans validation      |

## Le principe "never implement, never review"

kiss-orchestrator ne fait jamais de travail concret. Il ne touche pas au code. Il ne revoit pas le code. Son role est exclusivement de :

1. Comprendre le besoin (protocole INIT)
2. Decouper en etapes (PLAN.md)
3. Suivre la progression (STATE.md)
4. Deleguer au bon agent
5. Synthetiser a la fermeture

Ce principe empeche l'orchestrateur de court-circuiter le processus. Meme si la tache semble triviale, elle passe par kiss-executor pour l'implementation et kiss-verificator pour la review.

## Pourquoi la delegation explicite plutot qu'implicite ?

Quand kiss-orchestrator identifie une tache pour kiss-executor, il ne l'execute pas silencieusement. Il demande :

```
That's kiss-executor territory. Delegate? (yes / handle it yourself)
```

Cette delegation explicite sert plusieurs objectifs :

- **Transparence** : l'humain voit exactement qui fait quoi et quand
- **Controle** : l'humain peut choisir de faire le travail lui-meme
- **Tracabilite** : chaque delegation est inscrite dans CHECKPOINT.yaml
- **Correction** : si l'orchestrateur se trompe d'agent, l'humain peut corriger

## La boucle d'amelioration continue

kiss-improver ferme la boucle. Apres une session de travail, il analyse les transcripts pour identifier :

- Les frictions (corrections repetees, malentendus)
- Les lacunes (informations manquantes dans les memoires)
- Les derives (agents sortant de leur perimetre)
- Les patterns positifs (taches reussies du premier coup)

Ces observations deviennent des propositions concretes : ajouter une regle dans la memoire d'un agent, mettre a jour CLAUDE.md, etc. L'humain valide avant toute application.

C'est un systeme d'apprentissage collectif : les erreurs d'une session deviennent des gardes-fous pour les suivantes.
