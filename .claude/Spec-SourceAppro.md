# Mode opératoire — Socle de détermination de la source d'approvisionnement

## Remplacement du programme « commande à passer » — maquettes des deux alternatives

| Attribut | Valeur |
|---|---|
| Référence du document | MO-SRCAPPRO-2021FPS02-v1.0 |
| Documents liés | [MO Cockpit réservations](Spec.md) |
| Objets créés | Socle CDS de détermination de source + 4 applications Fiori (2 alternatives) |
| Périmètre | Réservation magasin, réapprovisionnement manuel du centre, commande petite caisse |
| Architecture | CDS analytique et transactionnel, OData V2, Gateway embedded, Fiori elements V2 |
| Version produit | SAP S/4HANA 2021 FPS02 — SAPUI5 1.96 |
| Statut | Maquettes pour arbitrage — aucune décision d'architecture n'est figée |

---

## 1. Contexte et enjeu

### 1.1 La situation actuelle

Le programme « commande à passer » de SAP Retail Store (SRS) représente **plus de 600 000 appels**, auxquels
s'ajoutent deux programmes qui en découlent directement, soit **plus de 1,5 million d'appels** au total.
Un écran unique porte aujourd'hui deux processus de nature différente.

### 1.2 La cible

Scinder cet écran en **deux processus distincts** :

| Processus | Contenu | Attente |
|---|---|---|
| Commande de réservation | Traitement des réservations transmises par les magasins | Mutualiser avec toutes les options d'approvisionnement du centre |
| Commande de réapprovisionnement | Réapprovisionnement manuel du centre | S'appuyer sur une tuile Fiori standard |

Cette orientation répond à deux souhaits :

- **standardiser**, en s'appuyant sur une tuile Fiori standard pour le réapprovisionnement manuel des centres ;
- **relier la commande de réservation** aux processus de demande de cession et de commande petite caisse,
  c'est-à-dire mutualiser le processus de réservation avec l'ensemble des options d'approvisionnement à disposition
  du centre : fournisseur centralisé, fournisseur local, source interne, commande petite caisse.

### 1.3 Les flux actuels (rappel)

```
IDoc Z_CONF_CMD_RESA        IDoc Z_BON_CLT            IDoc Z_CREA_PR
        ▲                        │                         │
        │                        ▼                    statut commandé ?
        │                   ZTBON_CLT                      │ non
        │              (n° BT si prestation)               ▼
        │                                        DA C&C / C&F : ZR11, ZR12, ZR21, ZR22
        │                   ZTRESA_CLIENT         DA S&C / S&F : ZRE1, ZRE2
        │              (n° BT UCB si prestation)           │
        │                                                  ▼
        │                                   DA internet, non NFF, fournisseur NVC (ZC10)
        │                                            et pas de stock magasin ?
        │                          non ◄──────────────────┴──────────────► oui
        │              Transformation DA ⇒ CA                    Transformation DA ⇒ CA
        │              manuelle dans SRS  ⑴                      automatique et immédiate
        │              ou par job MM608 ⑵                        (Z_IDOC_INPUT_CREATE_PR)
        │                                   │
        └────── message ZR1 ◄─────── CA ZDI5 ou commande de transfert (W13) : ZCO5, ZXP5, ZDW1
```

Le **point ⑴** — la transformation manuelle dans SRS — est précisément ce que remplacent les maquettes décrites ici.

---

## 2. Le scénario « commande client » étudié en séance

### 2.1 Principe

S'appuyer sur une **commande client SAP** lors de l'intégration d'une réservation, en lien avec la demande d'achat,
lorsque celle-ci doit être traitée manuellement dans SRS (point ⑴).

Méthode envisagée :

1. ajout d'un job pour lier les DA non converties à une commande client ;
2. utilisation de la tuile standard Fiori de gestion des commandes client ;
3. ajout d'une méthode spécifique de détermination de la source d'approvisionnement (socle commun, partie 4) ;
4. suivi de la commande client par le standard.

**Avantage identifié** : la gestion des cas particuliers. En cas de litige sur une commande d'achat liée à une
réservation, la commande client permet de régénérer un nouveau besoin d'approvisionnement, potentiellement depuis
une autre source — par exemple la création d'une STO depuis une division.

### 2.2 Avis exprimés

| Rôle | Position | Argument |
|---|---|---|
| Métier | Défavorable | La commande client relève du logiciel magasin ; SAP se limite au réapprovisionnement. Le scénario brouille les périmètres de responsabilité de chaque outil. **Risque que le projet n'aboutisse pas : anticiper un plan B.** |
| Consultant projet | Favorable sous réserve | Intérêt des tuiles standard de commande client pour gérer et suivre les états, malgré la complexité d'un nouvel objet, un risque sur le sizing machine et l'ajout de règles d'archivage. |
| Chef de projet | Réservé | La commande client ne résout pas la complexité : `ZTBON_CLT` et `ZTRESA_CLIENT` restent présentes et à maintenir. **La vraie complexité est la détermination de la source d'approvisionnement.** |

### 2.3 Conséquence retenue pour les maquettes

L'arbitrage n'est pas tranché ici. Les deux alternatives ci-dessous sont maquettées **à iso-données**, sur un socle
commun qui reste valable y compris dans le scénario commande client (la détermination de source serait alors appelée
depuis la commande client). Le socle est donc un **investissement sans regret**, quel que soit l'arbitrage.

---

## 3. Les deux alternatives maquettées

### 3.1 Alternative 1 — rationalisation autour de deux tuiles

| Tuile | Application | Contenu |
|---|---|---|
| Créer une demande d'achat | `zlr.alt1creation` | Création d'un besoin interne au centre (réapprovisionnement manuel) |
| Détermination de la source | `zlr.alt1source` | **Toutes** les DA (réappro manuel et réservation), sans création possible depuis l'écran, conversion DA ⇒ CA |

### 3.2 Alternative 2 — split conforme à l'attente métier et archi

| Tuile | Application | Contenu |
|---|---|---|
| Commande de réapprovisionnement | `zlr.alt2creation` | Création appelant la détermination de source **dès la saisie**, aboutissant à une commande d'achat |
| Réservations à approvisionner | `zlr.alt2source` | Préfiltre sur les DA de réservation à basculer en CA, avec bascule en commande petite caisse si aucun approvisionnement fournisseur n'est disponible |

### 3.3 Ce qui distingue les deux alternatives

| Critère | Alternative 1 | Alternative 2 |
|---|---|---|
| Séparation des processus | Partielle : un seul écran de détermination pour les deux flux | Complète : un parcours par processus |
| Proximité du standard | Écran de détermination spécifique | Création proche d'une extension de tuile standard |
| Lisibilité pour l'utilisateur magasin | Une seule liste à traiter | Deux entrées selon le besoin |
| Charge de conduite du changement | Plus faible (un écran de travail) | Plus élevée (deux parcours) |

---

## 4. Socle commun — la détermination de la source d'approvisionnement

C'est le cœur du dispositif et **le point de concentration de la complexité**. Il est identique dans les deux
alternatives, et resterait identique dans le scénario commande client.

### 4.1 Ce que le socle doit restituer, par ligne de commande (niveau poste)

| Source | Vue CDS | À brancher en réel |
|---|---|---|
| Fournisseurs EDI, disponibilité « A » | `ZI_ResaSrcEdi` | Contrôle fournisseur du message `ZC10`, restriction aux fournisseurs EDI (dont NVC) |
| Centres voisins, stock disponible à la vente | `ZI_ResaSrcStore` | Table de proximité (zone de chalandise, distance, tournée) et stock ATP vendable |
| Entrepôt (WH xxx) | `ZI_ResaSrcWhse` | Divisions entrepôt du périmètre, stock réellement disponible |
| Commande petite caisse | `ZI_ResaSrcCash` | Plafond d'éligibilité paramétré par centre et par dépense |

Ces quatre vues sont réunies par `ZI_ResaSourceAvail` (une ligne par poste **et par source candidate**), consommée
par `ZC_ResaSourceOption`. La liste de travail `ZC_ResaPurReqWorklist` restitue un poste par ligne avec le nombre de
sources, la source retenue et le statut d'avancement.

### 4.2 Règle de proposition

**Aucune proposition automatique.** L'écran restitue les options côte à côte (type, source, disponibilité, quantité,
délai, prix) et le choix reste manuel. Si une priorité devait être introduite plus tard, elle se matérialiserait par
un champ de rang calculé dans `ZI_ResaSourceAvail`, **sans impact sur les écrans**.

### 4.3 Actions exposées

| Action | Effet |
|---|---|
| `AssignSource` | Enregistre la source retenue pour le poste (une seule à la fois) |
| `ConvertToPurchaseOrder` | Crée la commande d'achat et solde le poste |
| `CreatePettyCashOrder` | Crée un document `ZPC` rattaché à la réservation et au poste, et solde le poste |
| `CreatePurchaseRequisition` | Alternative 1 : crée un besoin interne (DA) |
| `CreateReplenishmentOrder` | Alternative 2 : crée le besoin et la commande d'achat avec la source saisie |

Les deux actions de création sont annotées **sans contexte** : Fiori elements génère lui-même le formulaire de
saisie des paramètres du function import, sans code spécifique.

> **Note maquette** — les actions sont appelées par les écrans via `callFunction` (OData V2), ce qui a été vérifié
> en local. Un appel REST direct doit fournir un corps JSON `{}` en plus des paramètres d'URL, faute de quoi le
> mock server retourne une erreur 500 : c'est une limite du mock server, sans incidence sur les applications ni
> sur le back-end réel.

### 4.4 Traçabilité de la commande petite caisse

La commande petite caisse est un **document traçable** (`ZC_ResaPettyCashOrder`, type `ZPC`), rattaché à la
réservation d'origine. Le cube `ZI_ResaChainCube` porte désormais `FollowOnDocument` / `FollowOnDocumentType` et
l'étape `PC`, si bien que l'achat local apparaît dans le suivi de la chaîne au même titre qu'une commande d'achat.
Un poste soldé en petite caisse **n'est plus compté** dans les postes en attente du cockpit.

---

## 5. Modèle de données

| Vue | Rôle |
|---|---|
| `ZI_ResaSrcEdi`, `ZI_ResaSrcWhse`, `ZI_ResaSrcStore`, `ZI_ResaSrcCash` | Les quatre familles de sources |
| `ZI_ResaSourceAvail` | Union des sources : une ligne par poste et par source |
| `ZC_ResaSourceOption` | Consommation : comparatif affiché dans la page objet |
| `ZC_ResaPurReqWorklist` | Liste de travail : un poste par ligne, source retenue, statut |
| `ZC_ResaPettyCashOrder` | Documents petite caisse |
| `ZI_ResaChainCube` (étendu) | Document aval et étape `PC` |

Tables de persistance à créer : `ZTRESA_SRCSEL` (choix de source par poste) et `ZTRESA_PCORDER` (commandes petite
caisse), ainsi que la table de proximité des centres voisins.

Un **seul service** OData V2 expose l'ensemble : `ZCRESASRC_CDS`. Les quatre applications le consomment, ce qui
garantit la comparaison à iso-données.

---

## 6. Écrans

### 6.1 Écrans de détermination (Alternatives 1 et 2)

- **Liste** : poste, réservation, origine, division, article, quantité, date de besoin, nombre de sources
  (dont fournisseurs), source retenue, statut, document aval.
- **Page objet** : trois sections — *Besoin*, *Sources d'approvisionnement disponibles* (le comparatif), *Approvisionnement retenu*.
- **En-tête** : synthèse mutualisée (`zresa.sourcecommon`) avec l'alerte « aucune source fournisseur : la commande
  petite caisse est la seule option ».
- **Actions** : retenir une source (par ligne du comparatif), convertir en commande d'achat, créer une commande
  petite caisse, revenir au cockpit.

### 6.2 Écrans de création

Formulaire : division, article, désignation, quantité, date de besoin — plus, en Alternative 2, le type et
l'identifiant de la source. Le besoin créé apparaît immédiatement dans l'écran de détermination.

### 6.3 Mutualisation de l'interface

Le fragment partagé (`apps/sourcecommon/SourceGuidance.fragment.xml`) est chargé par les deux écrans de
détermination via `resourceRoots` et le point d'extension `BeforeFacet|ZC_ResaPurReqWorklist|Sources`, ce qui
démontre concrètement que le mécanisme est commun et non dupliqué.

Les écrans de création n'ont besoin d'aucun code : les actions `CreatePurchaseRequisition` et
`CreateReplenishmentOrder` sont annotées en `DataFieldForAction` sans contexte, et Fiori elements génère
lui-même le formulaire de saisie des paramètres.

> **⚠️ Écart assumé de la maquette**
> Les quatre applications partagent un **service unique**, donc un seul jeu d'annotations. Les boutons de
> création apparaissent par conséquent aussi dans les écrans de détermination, alors que l'Alternative 1
> prévoit explicitement une tuile de détermination **sans création possible**. Dans la cible, chaque tuile
> disposerait de sa propre vue de consommation (`ZC_ResaPurReqWorklist` pour la détermination,
> `ZC_ResaPurReqCreate` pour la création), portant ses propres annotations. Ce découpage n'a pas été fait
> dans la maquette pour garder la comparaison à iso-données entre les deux alternatives.

---

## 7. Grille d'arbitrage proposée

| Critère | À évaluer sur les maquettes |
|---|---|
| Respect des périmètres de responsabilité | L'objet manipulé reste-t-il dans le périmètre SAP (réapprovisionnement) ? |
| Complexité résiduelle | Nombre d'objets et de tables spécifiques à maintenir |
| Proximité du standard | Part d'écran standard vs spécifique |
| Volumétrie et sizing | Objets créés par réservation ; besoin de règles d'archivage |
| Couverture des cas particuliers | Litige, régénération d'un besoin depuis une autre source |
| Conduite du changement | Nombre de parcours utilisateurs en magasin |

---

## 8. Questions ouvertes

1. **Disponibilité « A »** : quelle définition exacte côté `ZC10` (stock fournisseur, délai, contrat) ?
2. **Centres voisins** : quel périmètre (distance, tournée de transport, zone) et quel stock (ATP vendable) ?
3. **Petite caisse** : plafond, circuit de justificatif, imputation comptable, qui valide ?
4. **Litige et régénération du besoin** : sans commande client, quel objet porte la reprise du besoin ?
5. **Devenir de `ZTBON_CLT` et `ZTRESA_CLIENT`** : maintenues, réduites ou supprimées dans la cible ?
6. **Plan B** : si le scénario commande client n'est pas retenu, quelle trajectoire pour le suivi des états ?
7. **Volumétrie** : combien de postes à traiter par centre et par jour, pour dimensionner l'écran de travail ?

---

## 9. Maquettes — où regarder

| Élément | Emplacement |
|---|---|
| Vues CDS et extensions | [`cds/`](../cds/) |
| Service et données mockées | [`apps/alt1source/webapp/localService/ZCRESASRC_CDS/`](../apps/alt1source/webapp/localService/ZCRESASRC_CDS/) |
| Extension mutualisée | [`apps/sourcecommon/`](../apps/sourcecommon/) |
| Applications | `apps/alt1creation`, `apps/alt1source`, `apps/alt2creation`, `apps/alt2source` |
| Lancement | `npm run start:launchpad` puis les groupes de tuiles « Alternative 1 » et « Alternative 2 » |

> **⚠️ Ce que les maquettes ne décident pas**
> Elles ne tranchent ni l'usage de la commande client, ni le choix entre les deux alternatives. Elles servent à
> comparer, sur des données identiques, ce que voit et fait l'utilisateur du centre.
