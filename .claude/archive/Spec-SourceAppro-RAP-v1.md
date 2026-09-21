# Mode opératoire — Détermination de la source d'approvisionnement en RAP

## Réalisation cible du socle commun sur ABAP RESTful Application Programming Model

| Attribut | Valeur |
|---|---|
| Référence du document | MO-SRCAPPRO-RAP-2021FPS02-v1.0 |
| Documents liés | [MO Socle source d'approvisionnement (maquettes)](Spec-SourceAppro.md) · [MO Cockpit réservations](Spec.md) |
| Objets créés | 8 tables (3 applicatives, 5 de customizing), 1 tranche de numéros, 1 objet d'autorisation, vues CDS d'interface, 2 business objects RAP, 4 projections, 4 services OData V4, 4 applications Fiori elements V4, 2 rôles |
| Périmètre | Détermination de la source par poste de DA (Alternative 1 et Alternative 2), commande d'achat / de transfert, commande petite caisse, création d'un besoin de réapprovisionnement |
| Architecture | 100 % ABAP — RAP managed avec sauvegarde non managée, OData V4, Fiori elements V4, **sans draft** |
| Version produit | SAP S/4HANA 2021 FPS02 — SAPUI5 1.96 |
| Package | `ZRESA_SRC` |
| Outils | Eclipse + ABAP Development Tools · VS Code + SAP Fiori tools · SAP GUI |
| Auteur | … |
| Vérifié par | … |
| Date de rédaction | … |
| Statut | Version de travail |

> **Convention de ce document**
> - Chaque emplacement de copie d'écran est signalé par un bloc `📸 COPIE D'ÉCRAN N°XX`. Déposer les images dans
>   `images/RESA-SRC-RAP/`.
> - Toute valeur **non confirmée** est écrite `⟨ENTRE_CHEVRONS⟩` et reprise dans
>   l'[annexe C — Paramètres à renseigner](#annexe-c--paramètres-à-renseigner). Le code qui en contient ne
>   s'active pas tant qu'elles ne sont pas remplacées : c'est volontaire.
> - Les encadrés **⚠️ À vérifier** signalent un nom de champ standard ou une capacité RAP à contrôler dans le
>   système avant activation, comme dans le MO du cockpit (§A3).

---

## Sommaire

- [1. Objet et décisions de conception](#1-objet-et-décisions-de-conception)
- [2. Prérequis](#2-prérequis)
- [3. Architecture et synoptique](#3-architecture-et-synoptique)
- [Partie A — Persistance](#partie-a--persistance)
- [Partie B — Customizing](#partie-b--customizing)
- [Partie C — Vues CDS d'interface](#partie-c--vues-cds-dinterface)
- [Partie D — Business objects RAP](#partie-d--business-objects-rap)
- [Partie E — Implémentation ABAP](#partie-e--implémentation-abap)
- [Partie F — Projections et annotations](#partie-f--projections-et-annotations)
- [Partie G — Services OData V4](#partie-g--services-odata-v4)
- [Partie H — Applications Fiori elements V4](#partie-h--applications-fiori-elements-v4)
- [Partie I — Rôles, autorisations et launchpad](#partie-i--rôles-autorisations-et-launchpad)
- [Partie J — Recette, transport et exploitation](#partie-j--recette-transport-et-exploitation)
- [Annexe A — Diagnostic des incidents fréquents](#annexe-a--diagnostic-des-incidents-fréquents)
- [Annexe B — Correspondance maquette V2 → RAP](#annexe-b--correspondance-maquette-v2--rap)
- [Annexe C — Paramètres à renseigner](#annexe-c--paramètres-à-renseigner)
- [Annexe D — Index des copies d'écran](#annexe-d--index-des-copies-décran)
- [Annexe E — Historique des versions](#annexe-e--historique-des-versions)

---

## 1. Objet et décisions de conception

### 1.1 Objet

Les maquettes du [MO Socle source d'approvisionnement](Spec-SourceAppro.md) restituent la détermination de la
source sur des vues CDS classiques publiées en OData V2, avec des actions simulées par le mock server. Ce mode
opératoire décrit la **réalisation réelle** de ce socle, **exclusivement en RAP** : la persistance du choix, la
création des documents aval et les contrôles sont portés par des business objects, et non par un programme ou
des function imports codés à la main.

Il reste valable **quel que soit l'arbitrage** entre les deux alternatives : un seul business object porte la
logique, deux projections l'exposent.

### 1.2 Décisions retenues

| Sujet | Décision | Conséquence |
|---|---|---|
| Périmètre | **Un BO de détermination, deux projections** (Alternative 1 : toutes les DA ; Alternative 2 : réservations) + un BO de création de besoin | Logique écrite une seule fois ; chaque tuile a ses propres annotations |
| Protocole | **OData V4**, Fiori elements V4 | Les quatre applications maquettes V2 sont régénérées en V4 |
| Draft | **Sans draft** | Les actions écrivent directement ; pas de tables draft ; verrou pessimiste sur la DA |
| Document aval | Fournisseur EDI → **CA `ZDI5`** ; entrepôt et centre voisin → **commande de transfert**, type **paramétré** ; petite caisse → **document `ZPC`** | Table `ZTRESA_SRCDOCTY` |
| Création CA / STO | **`BAPI_PO_CREATE1` en phase de sauvegarde RAP**, sans `COMMIT` | Sauvegarde non managée (`with unmanaged save`) |
| Création DA (Alt. 1) | **`BAPI_PR_CREATE`** en phase de sauvegarde | BO `ZR_ResaReplenRequest` |
| Plafond petite caisse | **Par division** (montant + devise) | Table `ZTRESA_PCLIMIT` |
| Numérotation `ZPC` | **Tranche de numéros SNRO** `ZRESA_PC`, numérotation tardive | `adjust_numbers` |
| Autorisations | Objets **standard achats** (`M_BANF_WRK`, `M_BEST_WRK`, `M_BEST_BSA`) ; objet **Z** `ZRESA_PC` pour la petite caisse uniquement | DCL + contrôles d'instance |
| Disponibilité fournisseur | **Table Z existante alimentée par `ZC10`** | Nom et champs : `⟨TABLE_ZC10⟩` à renseigner |
| Centres voisins | Table Z division → voisins (rang, délai) | `ZTRESA_NEIGHB` |
| Entrepôts | Table Z division → entrepôts livreurs (rang, délai) | `ZTRESA_WHSE` |
| Règle de proposition | **Aucune proposition automatique** (inchangé) : comparatif, choix manuel | Le champ de rang est restitué mais n'ordonne rien d'autorité |

### 1.3 Ce que le RAP remplace dans la maquette

| Maquette (V2) | Réalisation RAP |
|---|---|
| `@OData.publish: true` sur les vues de consommation | Service definition + service binding OData V4 |
| Function import `AssignSource` | Action d'instance `SelectSource` sur la ligne d'option de source |
| Function import `ConvertToPurchaseOrder` | Action d'instance sur le poste, création réelle en sauvegarde |
| Function import `CreatePettyCashOrder` | Action d'instance + création par association de l'entité `PettyCash` |
| Function imports `CreatePurchaseRequisition` / `CreateReplenishmentOrder` | Actions statiques du BO `ZR_ResaReplenRequest` |
| Plafond petite caisse en dur (200) | `ZTRESA_PCLIMIT` |
| Disponibilité EDI en dur (`'A'`) | `⟨TABLE_ZC10⟩` |
| Entrepôts filtrés sur `like 'WH%'` | `ZTRESA_WHSE` |
| Vue `ZI_ResaStoreNeighbour` « à créer » | `ZTRESA_NEIGHB` |
| Écart assumé : boutons de création dans l'écran de détermination | **Résolu** : une projection et une extension de métadonnées par tuile |

### 1.4 Hors périmètre

- Alimentation de `⟨TABLE_ZC10⟩` par le message `ZC10` (existant, non modifié).
- Intégration des réservations par IDoc `Z_CREA_PR` et champ de réservation dans la DA (supposés en place, cf. [MO Cockpit](Spec.md) §2.1).
- Scénario commande client (§2 du MO maquettes) : le BO pourra être appelé depuis ce scénario par EML, sans modification.
- Circuit de justificatif, imputation comptable et validation de la petite caisse (question ouverte n°3 du MO maquettes).
- Règle de priorisation automatique des sources.

---

## 2. Prérequis

### 2.1 Prérequis fonctionnels

| Élément | Exigence | Responsable |
|---|---|---|
| Champ de réservation | Présent dans la DA et exposé dans `I_PurchaseRequisitionItem` (`ZZReservation`) | Déjà traité par le MO cockpit |
| Types de document | `ZDI5` et types de commande de transfert existants et paramétrés (MM) | Fonctionnel MM |
| Type de DA de réapprovisionnement manuel | Existant, par division | Fonctionnel MM — `⟨TYPE_DA_REAPPRO⟩` |
| Organisation d'achat / groupe d'acheteurs par division et type de source | Connus | Fonctionnel MM |
| Transfert entre divisions | Paramétrage STO en place (division livreuse, type de livraison) | Fonctionnel MM / SD |
| Table `ZC10` | Nom, champs fournisseur / article / (division) / disponibilité, signification des codes | Équipe interface — `⟨TABLE_ZC10⟩` |
| Plafonds petite caisse | Montant et devise par division | Métier |
| Centres voisins et entrepôts | Liste par division, rang, délai | Métier / supply chain |

### 2.2 Prérequis techniques

| Élément | Exigence |
|---|---|
| Plateforme | SAP S/4HANA 2021 FPS02 (ABAP 7.56) |
| ADT | Version à jour, compatible avec le niveau 7.56 (éditeurs *Behavior Definition*, *Service Binding*) |
| VS Code | SAP Fiori tools, générateur *List Report Page* OData V4 |
| Autorisations développeur | `S_DEVELOP`, `S_TRANSPRT`, `S_NUMBER` (SNRO), SU21, PFCG, `/IWFND/V4_ADMIN` |
| Package / transport | Package `ZRESA_SRC`, un ordre workbench, un ordre customizing |

### 2.3 Relevés à faire avant de coder

Ne rien deviner : chaque ligne ci-dessous conditionne le code des parties C à E.

| N° | Relevé | Où | Utilisé en |
|---|---|---|---|
| R1 | Noms réels dans `I_PurchaseRequisitionItem` : `ZZReservation`, `PurchaseOrder`, `PurchaseOrderItem`, `DeliveryDate`, `PurchaseRequisitionPrice`, unité de prix, indicateur de suppression, indicateur de clôture | ADT, *Open Data Preview* + *Element Info* | C4, D1 |
| R2 | Vue de données organisationnelles de la fiche info (nom supposé `I_PurgInfoRecdOrgPlntData`) : champs division, organisation d'achat, catégorie, prix net, délai prévisionnel | ADT | C1 |
| R3 | Vue de stock utilisée pour entrepôt et centre voisin (ex. `I_MaterialStock_2`) et champ de stock libre ; décision stock libre / ATP (question ouverte n°2 du MO maquettes) | ADT + métier | C2 |
| R4 | Objet de verrouillage de la table `EBAN` et noms de ses paramètres | SE11 → *Objets de verrouillage*, recherche sur la table `EBAN` | E1 |
| R5 | `⟨TABLE_ZC10⟩` : nom, champs, codes de disponibilité | SE11 | C1 |
| R6 | Capacités RAP du système : `strict`, `provider contract`, `late numbering` en managed, `union` dans une *view entity*, fonction `get_numeric_value` | Créer un objet de test dans `$TMP` | C, D, F |
| R7 | Format attendu par `BAPI_PR_CREATE` et `BAPI_PO_CREATE1` pour la date de livraison et l'unité (interne / externe / ISO) | SE37, exécution test sans commit | E5 |

> **⚠️ Capacités RAP à confirmer (R6)**
> Les éléments de syntaxe `strict;`, `provider contract transactional_query`, `late numbering` sur une entité
> managed et `union all` dans une `define view entity` sont utilisés dans ce document. S'ils sont refusés par
> le compilateur du système :
> - `strict;` → retirer la ligne (la sémantique ne change pas) ;
> - `provider contract transactional_query` → retirer la clause ;
> - `union all` en view entity → créer la vue d'union en vue classique (`define view` + `@AbapCatalog.sqlViewName`), les view entities peuvent la consommer ;
> - `late numbering` → voir le repli en [annexe A](#annexe-a--diagnostic-des-incidents-fréquents).

> **📸 COPIE D'ÉCRAN N°01** — ADT : aperçu de `I_PurchaseRequisitionItem`, champs relevés en R1
> *Remplacer cette ligne par :* `![Copie 01](images/RESA-SRC-RAP/capture-01.png)`

> **📸 COPIE D'ÉCRAN N°02** — SE11 : objet de verrouillage de `EBAN` et ses paramètres (R4)
> *Remplacer cette ligne par :* `![Copie 02](images/RESA-SRC-RAP/capture-02.png)`

---

## 3. Architecture et synoptique

### 3.1 Vue d'ensemble

```
CUSTOMIZING (classe C)   ZTRESA_SRCDOCTY  ZTRESA_REPLCFG  ZTRESA_PCLIMIT  ZTRESA_NEIGHB  ZTRESA_WHSE
EXISTANT                 ⟨TABLE_ZC10⟩     I_PurchaseRequisitionItem   fiches info   stock
                                  │
INTERFACE (C)            ZI_ResaSrcEdi   ZI_ResaSrcWhse   ZI_ResaSrcStore      (division × article × source)
                                  └──────────┬──────────┘
                                   ZI_ResaSrcCandidate (union)  ───►  ZI_ResaSrcCandidateVH
                                             │
                                   ZI_ResaSourceAvail  (poste de DA × source, + CASH)
                                             │
                                   ZI_ResaSourceCount  (nombre de sources par poste)
                                             │
BO DÉTERMINATION (D)     ZR_ResaPurReqSource ─┬─ composition ─► ZR_ResaSourceOption  (lecture seule)
  persistance A          (ZTRESA_SRCSEL)      └─ composition ─► ZR_ResaPettyCash     (ZTRESA_PCORDER, SNRO)
BO CRÉATION (D)          ZR_ResaReplenRequest (ZTRESA_REPLREQ)
                                             │
PROJECTIONS (F)          Alt. 1 : ZC_ResaPurReqSourceAll  (+ ZC_ResaSourceOptAll, ZC_ResaPettyCashAll)
                                  ZC_ResaReplenRequestPR
                         Alt. 2 : ZC_ResaPurReqSourceResa (+ ZC_ResaSourceOptResa, ZC_ResaPettyCashResa)
                                  ZC_ResaReplenRequestPO
                                             │
SERVICES V4 (G)          ZUI_RESASRC_ALT1   ZUI_RESAREPL_ALT1   ZUI_RESASRC_ALT2   ZUI_RESAREPL_ALT2
                                             │
APPLICATIONS (H)         zlr.alt1source     zlr.alt1creation    zlr.alt2source     zlr.alt2creation
```

### 3.2 Pourquoi « managed with unmanaged save »

| Contrainte | Réponse |
|---|---|
| La racine est le **poste de DA standard** : la ligne de choix de source (`ZTRESA_SRCSEL`) n'existe pas tant que l'utilisateur n'a rien retenu | La sauvegarde managée ne sait faire qu'un `UPDATE` d'une ligne existante ; la sauvegarde non managée fait un `MODIFY` (création ou mise à jour) |
| La commande doit être **réellement créée** par `BAPI_PO_CREATE1` | Appel dans `save_modified`, seul endroit où une mise à jour hors BO est autorisée |
| Le tampon transactionnel, les actions, le contrôle des fonctionnalités et des autorisations restent standard | Partie « managed » conservée |

### 3.3 Cycle de vie d'un poste

| `SourceStatus` | Libellé | Atteint par | Actions possibles |
|---|---|---|---|
| `TODO` | À traiter | Poste de DA ouvert sans choix | Retenir une source |
| `SEL` | Source choisie | `SelectSource` | Retenir une autre source, convertir (si source ≠ petite caisse), petite caisse (si éligible) |
| `REQ` | Conversion demandée | `ConvertToPurchaseOrder` (état transitoire dans la requête) | — |
| `ERR` | Échec de conversion | Retour en erreur de la BAPI | Retenir une source, convertir à nouveau |
| `CONV` | Approvisionnement lancé | CA / STO créée, ou document `ZPC` créé | — |

### 3.4 Synoptique des étapes

| N° | Étape | Objet | Partie |
|---|---|---|---|
| A1 | Créer les domaines et éléments de données | `ZRESA_SRCTYPE`, `ZRESA_PROCSTAT`, `ZRESA_PCSTAT` | A |
| A2 | Créer les tables applicatives | `ZTRESA_SRCSEL`, `ZTRESA_PCORDER`, `ZTRESA_REPLREQ` | A |
| A3 | Créer la tranche de numéros | `ZRESA_PC` | A |
| A4 | Créer la classe de messages | `ZRESA_SRC` | A |
| B1 | Créer les tables de customizing | 5 tables `ZTRESA_…` | B |
| B2 | Générer la maintenance SM30 | Groupe de fonctions `ZRESA_SRC_TMG` | B |
| B3 | Saisir le paramétrage initial | Ordre de customizing | B |
| C1 à C6 | Vues CDS d'interface et contrôle d'accès | `ZI_Resa…` | C |
| D1 à D5 | Vues du BO, entités abstraites, behavior definitions | `ZR_Resa…`, `ZD_Resa…` | D |
| E1 à E6 | Classes d'implémentation et classes utilitaires | `ZBP_R_…`, `ZCL_RESA_SRC_…` | E |
| F1 à F4 | Projections, behavior de projection, extensions de métadonnées, DCL | `ZC_Resa…` | F |
| G1 à G3 | Service definitions, bindings, publication | `ZUI_…` | G |
| H1 à H5 | Génération et configuration des applications | 4 applications | H |
| I1 à I5 | Objet d'autorisation, rôles, catalogues, tuiles | PFCG, launchpad | I |
| J | Recette, transport, exploitation | — | J |

---

## Partie A — Persistance

### A1 — Domaines et éléments de données

Créer dans ADT (*New → Other ABAP Repository Object → Dictionary*) ou SE11, package `ZRESA_SRC`.

| Domaine | Type | Valeurs fixes | Élément de données | Libellé |
|---|---|---|---|---|
| `ZRESA_SRCTYPE` | `CHAR 4` | `EDI` Fournisseur EDI · `WHSE` Entrepôt · `STOR` Centre voisin · `CASH` Commande petite caisse | `ZRESA_SRCTYPE` | Type de source |
| `ZRESA_SRCID` | `CHAR 10` | — | `ZRESA_SRCID` | Identifiant de source |
| `ZRESA_PROCSTAT` | `CHAR 4` | `SEL` Source choisie · `REQ` Conversion demandée · `ERR` Échec de conversion · `CONV` Approvisionnement lancé | `ZRESA_PROCSTAT` | Statut de traitement |
| `ZRESA_PCSTAT` | `CHAR 2` | `CR` Créée · `JU` Justificatif reçu · `CL` Soldée | `ZRESA_PCSTAT` | Statut petite caisse |
| `ZRESA_REQTYPE` | `CHAR 2` | `PR` Demande d'achat · `PO` Commande de réapprovisionnement | `ZRESA_REQTYPE` | Type de besoin |
| `ZRESA_PCNUM` | `CHAR 10` | — | `ZRESA_PCNUM` | N° commande petite caisse |
| `ZRESA_RESNUM` | `CHAR 20` | — | `ZRESA_RESNUM` | Réservation |

> **⚠️ À vérifier** — la longueur de `ZRESA_RESNUM` doit être celle du champ de réservation de la DA (relevé R1).

> **ℹ️ Pourquoi des valeurs fixes de domaine**
> Elles fournissent les libellés traduisibles et l'aide à la saisie du type de source (vue
> `ZI_ResaSourceTypeVH`, étape C6) sans table supplémentaire.

---

### A2 — Tables applicatives

Classe de livraison **A**, catégorie d'extension *non extensible*, maintenance des données **restreinte**
(ces tables ne sont écrites que par les BO).

#### A2.1 `ZTRESA_SRCSEL` — choix de source par poste de DA

```abap
@EndUserText.label : 'Choix de source d''appro par poste de DA'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztresa_srcsel {
  key client      : abap.clnt not null;
  key banfn       : banfn not null;
  key bnfpo       : bnfpo not null;
  srctype         : zresa_srctype;
  srcid           : zresa_srcid;
  bsart           : esart;
  status          : zresa_procstat;
  ebeln           : ebeln;
  msgtxt          : bapi_msg;
  created_by      : abp_creation_user;
  created_at      : abp_creation_tstmpl;
  last_changed_by : abp_lastchange_user;
  last_changed_at : abp_lastchange_tstmpl;
}
```

| Champ | Rôle |
|---|---|
| `srctype`, `srcid` | Source retenue |
| `bsart` | Type de document déterminé au moment du choix (sert au contrôle `M_BEST_BSA`) |
| `status` | `SEL`, `REQ`, `ERR`, `CONV` |
| `ebeln` | Document créé (trace ; la référence faisant foi reste celle de la DA) |
| `msgtxt` | Dernier message d'erreur de la BAPI |

#### A2.2 `ZTRESA_PCORDER` — commandes petite caisse

Mêmes champs que ceux lus par la vue maquette `ZC_ResaPettyCashOrder` et par `ZI_ResaChainCube` (jointure sur
`banfn` / `bnfpo`), ce qui garde le cockpit fonctionnel sans modification.

```abap
@EndUserText.label : 'Commandes petite caisse (ZPC)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztresa_pcorder {
  key client  : abap.clnt not null;
  key pcnum   : zresa_pcnum not null;
  banfn       : banfn;
  bnfpo       : bnfpo;
  resnum      : zresa_resnum;
  werks       : werks_d;
  matnr       : matnr;
  txz01       : txz01;
  @Semantics.quantity.unitOfMeasure : 'ztresa_pcorder.meins'
  menge       : menge_d;
  meins       : meins;
  @Semantics.amount.currencyCode : 'ztresa_pcorder.waers'
  netwr       : abap.curr(13,2);
  waers       : waers;
  lifname     : abap.char(80);
  status      : zresa_pcstat;
  erdat       : erdat;
  ernam       : ernam;
  created_at  : abp_creation_tstmpl;
}
```

Créer un **index secondaire** `Z01` sur `banfn`, `bnfpo` (lecture par poste depuis le BO et le cockpit).

#### A2.3 `ZTRESA_REPLREQ` — besoins de réapprovisionnement saisis

```abap
@EndUserText.label : 'Besoins de réapprovisionnement saisis'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztresa_replreq {
  key client      : abap.clnt not null;
  key req_uuid    : sysuuid_x16 not null;
  reqtype         : zresa_reqtype;
  werks           : werks_d;
  matnr           : matnr;
  txz01           : txz01;
  @Semantics.quantity.unitOfMeasure : 'ztresa_replreq.meins'
  menge           : menge_d;
  meins           : meins;
  lfdat           : eindt;
  srctype         : zresa_srctype;
  srcid           : zresa_srcid;
  bsart           : esart;
  status          : zresa_procstat;
  banfn           : banfn;
  ebeln           : ebeln;
  msgtxt          : bapi_msg;
  created_by      : abp_creation_user;
  created_at      : abp_creation_tstmpl;
}
```

> **⚠️ À vérifier** — les éléments de données `ABP_CREATION_USER`, `ABP_CREATION_TSTMPL`,
> `ABP_LASTCHANGE_USER`, `ABP_LASTCHANGE_TSTMPL` et `SYSUUID_X16` existent en 2021 ; en cas d'absence, utiliser
> `SYUNAME`, `TIMESTAMPL` et `RAW 16`.

> **📸 COPIE D'ÉCRAN N°03** — ADT : les trois tables applicatives activées
> *Remplacer cette ligne par :* `![Copie 03](images/RESA-SRC-RAP/capture-03.png)`

---

### A3 — Tranche de numéros `ZRESA_PC`

1. Transaction `SNRO`, objet `ZRESA_PC`, *Créer*.
2. Texte court : `Commande petite caisse` ; texte long : `Commandes petite caisse (réservations magasin)`.
3. Domaine de longueur de numéro : `ZRESA_PCNUM`.
4. Pas d'élément d'exercice, pas d'élément de sous-objet.
5. Pourcentage d'avertissement : `90`. Nombre de numéros en mémoire tampon : **`0`** (pas de trous, numéros
   attribués dans l'ordre de sauvegarde).
6. Enregistrer dans l'ordre workbench.
7. *Intervalles de numéros → Modifier intervalles* : intervalle `01`, de `⟨PC_NUM_DEBUT⟩` à `⟨PC_NUM_FIN⟩`,
   numérotation interne.

> **⚠️ Intervalles et transport**
> Les intervalles ne suivent pas l'objet dans l'ordre workbench. Décider en amont : création manuelle dans chaque
> système (recommandé : l'état courant n'est jamais écrasé) ou transport explicite depuis SNRO.

> **📸 COPIE D'ÉCRAN N°04** — SNRO : objet `ZRESA_PC` et son intervalle `01`
> *Remplacer cette ligne par :* `![Copie 04](images/RESA-SRC-RAP/capture-04.png)`

---

### A4 — Classe de messages `ZRESA_SRC`

Transaction `SE91` (ou ADT *Message Class*), package `ZRESA_SRC`.

| N° | Texte |
|---|---|
| 001 | Poste &1/&2 verrouillé par l'utilisateur &3 |
| 002 | Type de document non paramétré pour la source &1 en division &2 (ZTRESA_SRCDOCTY) |
| 003 | Aucune source retenue pour le poste &1/&2 |
| 004 | La petite caisse se traite par l'action « Commande petite caisse » |
| 005 | Pas d'autorisation pour créer une commande de type &1 |
| 006 | Pas d'autorisation pour la division &1 |
| 007 | Poste &1/&2 déjà approvisionné par le document &3 |
| 008 | Montant &1 supérieur au plafond petite caisse &2 de la division &3 |
| 009 | Plafond petite caisse non paramétré pour la division &1 (ZTRESA_PCLIMIT) |
| 010 | Le nom du fournisseur local est obligatoire |
| 011 | Le montant doit être strictement positif |
| 012 | Source &1 &2 non disponible pour l'article &3 en division &4 |
| 013 | Commande &1 créée pour le poste &2/&3 |
| 014 | Échec de création du document pour &1/&2 : &3 |
| 015 | Demande d'achat &1 créée |
| 016 | Paramétrage du réapprovisionnement manuel absent pour la division &1 (ZTRESA_REPLCFG) |
| 017 | Commande petite caisse &1 créée |
| 018 | La devise &1 ne correspond pas à la devise du plafond &2 |
| 019 | La quantité doit être strictement positive |

---

## Partie B — Customizing

### B1 — Tables de customizing

Classe de livraison **C**, maintenance des données **autorisée**. Un poste avec division à blanc sert de
**valeur par défaut** lorsque la division n'a pas de ligne propre (règle appliquée par la classe
`ZCL_RESA_SRC_CUSTO`, étape E4, pour `ZTRESA_SRCDOCTY`, `ZTRESA_REPLCFG` et `ZTRESA_PCLIMIT`).

#### B1.1 `ZTRESA_SRCDOCTY` — type de document par type de source

```abap
@EndUserText.label : 'Source d''appro : type de document et org. d''achat'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table ztresa_srcdocty {
  key client  : abap.clnt not null;
  key werks   : werks_d not null;
  key srctype : zresa_srctype not null;
  bsart       : esart;
  ekorg       : ekorg;
  ekgrp       : bkgrp;
}
```

| Champ | Rôle |
|---|---|
| `werks` | Division **réceptrice** (à blanc : défaut) |
| `srctype` | `EDI`, `WHSE`, `STOR` (`CASH` n'a pas de ligne : il ne produit pas de commande d'achat) |
| `bsart` | Type de document de commande (`ZDI5` pour `EDI` ; types de commande de transfert à renseigner) |
| `ekorg` | Organisation d'achat de la commande ; sert aussi à restreindre les fiches info en C1 |
| `ekgrp` | Groupe d'acheteurs ; à blanc, celui de la DA est repris |

#### B1.2 `ZTRESA_REPLCFG` — réapprovisionnement manuel par division

```abap
@EndUserText.label : 'Réapprovisionnement manuel : paramètres par division'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table ztresa_replcfg {
  key client : abap.clnt not null;
  key werks  : werks_d not null;
  bsart_pr   : bbsrt;
  ekgrp      : bkgrp;
}
```

#### B1.3 `ZTRESA_PCLIMIT` — plafond petite caisse par division

```abap
@EndUserText.label : 'Plafond de commande petite caisse par division'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table ztresa_pclimit {
  key client : abap.clnt not null;
  key werks  : werks_d not null;
  @Semantics.amount.currencyCode : 'ztresa_pclimit.waers'
  maxamount  : abap.curr(13,2);
  waers      : waers;
}
```

> **ℹ️ Défaut et CDS**
> La vue `ZI_ResaSourceAvail` (C4) lit le plafond de la division **puis** la ligne à blanc par une double
> jointure : le comportement est identique à l'écran et dans les contrôles ABAP.

#### B1.4 `ZTRESA_NEIGHB` — centres voisins

```abap
@EndUserText.label : 'Centres voisins par division'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table ztresa_neighb {
  key client : abap.clnt not null;
  key werks  : werks_d not null;
  key nbwerks: werks_d not null;
  srcrank    : abap.numc(2);
  leadtime   : abap.int2;
}
```

#### B1.5 `ZTRESA_WHSE` — entrepôts livreurs

```abap
@EndUserText.label : 'Entrepôts livreurs par division'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table ztresa_whse {
  key client : abap.clnt not null;
  key werks  : werks_d not null;
  key whwerks: werks_d not null;
  srcrank    : abap.numc(2);
  leadtime   : abap.int2;
}
```

Pas de division à blanc pour `ZTRESA_NEIGHB` et `ZTRESA_WHSE` : une division sans ligne n'a simplement pas de
source interne de ce type.

> **📸 COPIE D'ÉCRAN N°05** — ADT : les cinq tables de customizing activées
> *Remplacer cette ligne par :* `![Copie 05](images/RESA-SRC-RAP/capture-05.png)`

---

### B2 — Générer la maintenance SM30

Pour **chacune** des cinq tables :

1. `SE11` → table → *Utilitaires → Générateur de gestion de table*.
2. Groupe d'autorisations : `⟨GROUPE_AUTH_TABLE⟩` (à défaut `&NC&`, à valider par la sécurité).
3. Groupe de fonctions : `ZRESA_SRC_TMG` (le même pour les cinq), package `ZRESA_SRC`.
4. Type de maintenance : **une étape**.
5. Écran de synthèse : *Rechercher n° d'écran* → proposition du système.
6. Routine d'enregistrement : **routine d'enregistrement standard** (les saisies partent en ordre de customizing).
7. *Créer*, puis *Tester* par `SM30`.

> **📸 COPIE D'ÉCRAN N°06** — Générateur de gestion de table : paramètres de `ZTRESA_SRCDOCTY`
> *Remplacer cette ligne par :* `![Copie 06](images/RESA-SRC-RAP/capture-06.png)`

---

### B3 — Paramétrage initial à saisir

Saisir en `SM30` dans le système de développement customizing, sur un ordre de customizing.

| Table | Clé | Valeurs | Source de la valeur |
|---|---|---|---|
| `ZTRESA_SRCDOCTY` | division à blanc, `EDI` | `bsart = ZDI5`, `ekorg = ⟨EKORG_EDI⟩`, `ekgrp` à blanc | Décision projet (`ZDI5`) ; org. d'achat à fournir |
| `ZTRESA_SRCDOCTY` | division à blanc, `WHSE` | `bsart = ⟨TYPE_STO_ENTREPOT⟩`, `ekorg = ⟨EKORG_STO⟩` | Fonctionnel MM (types candidats cités par le flux : `ZCO5`, `ZXP5`, `ZDW1`) |
| `ZTRESA_SRCDOCTY` | division à blanc, `STOR` | `bsart = ⟨TYPE_STO_VOISIN⟩`, `ekorg = ⟨EKORG_STO⟩` | Fonctionnel MM |
| `ZTRESA_REPLCFG` | division à blanc | `bsart_pr = ⟨TYPE_DA_REAPPRO⟩`, `ekgrp = ⟨EKGRP_REAPPRO⟩` | Fonctionnel MM |
| `ZTRESA_PCLIMIT` | par division ou à blanc | `maxamount = ⟨PLAFOND_PC⟩`, `waers = ⟨DEVISE_PC⟩` | Métier (la maquette utilisait 200 à titre d'illustration) |
| `ZTRESA_NEIGHB` | division × voisin | rang, délai | Métier / supply chain |
| `ZTRESA_WHSE` | division × entrepôt | rang, délai | Métier / supply chain |

> **📸 COPIE D'ÉCRAN N°07** — SM30 : `ZTRESA_SRCDOCTY` renseignée
> *Remplacer cette ligne par :* `![Copie 07](images/RESA-SRC-RAP/capture-07.png)`

---

## Partie C — Vues CDS d'interface

Les vues de la maquette (`ZI_ResaSrcEdi`, `ZI_ResaSrcWhse`, `ZI_ResaSrcStore`, `ZI_ResaSrcCash`,
`ZI_ResaSourceAvail`) sont **remplacées** par des *view entities*. Changement structurant : les sources sont
d'abord déterminées **par division × article** (`ZI_ResaSrcCandidate`), sans dépendre d'une DA. C'est ce qui
permet à l'Alternative 2 de proposer les sources **dès la saisie**, avant que le besoin n'existe.

Création : ADT → *New → Data Definition*, modèle *Define View Entity*, package `ZRESA_SRC`.

### C1 — Fournisseurs EDI : `ZI_ResaSrcEdi`

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Source d''appro - fournisseurs EDI'

-- Un fournisseur est candidat pour une division et un article si :
--   - une fiche info existe pour l'organisation d'achat paramétrée (ZTRESA_SRCDOCTY, source EDI),
--   - il figure dans la table de disponibilité alimentée par le message ZC10.
-- ⚠️ R2 : noms de la vue org./division de la fiche info et de ses champs à confirmer.
-- ⚠️ R5 : ⟨TABLE_ZC10⟩ et ses champs à renseigner ; ajouter la condition sur la division si la table la porte.
define view entity ZI_ResaSrcEdi
  as select from    I_PurgInfoRecdOrgPlntData as OrgPlnt

    inner join      I_PurchasingInfoRecord    as InfoRecord
      on InfoRecord.PurchasingInfoRecord = OrgPlnt.PurchasingInfoRecord

    inner join      ztresa_srcdocty           as DocType
      on  DocType.werks   = ''
      and DocType.srctype = 'EDI'
      and DocType.ekorg   = OrgPlnt.PurchasingOrganization

    inner join      ⟨TABLE_ZC10⟩              as Zc10
      on  Zc10.⟨CHAMP_ZC10_FOURNISSEUR⟩ = InfoRecord.Supplier
      and Zc10.⟨CHAMP_ZC10_ARTICLE⟩     = InfoRecord.Material

    left outer join I_Supplier                as Supplier
      on Supplier.Supplier = InfoRecord.Supplier
{
  key OrgPlnt.Plant                                            as Plant,
  key InfoRecord.Material                                      as Material,
  key cast( 'EDI' as zresa_srctype )                           as SourceType,
  key cast( InfoRecord.Supplier as zresa_srcid )               as SourceId,

      cast( Supplier.SupplierName as abap.char(80) )           as SourceName,
      cast( Zc10.⟨CHAMP_ZC10_DISPO⟩ as abap.char(1) )          as SupplierAvailability,
      cast( 0 as abap.int2 )                                   as SourceRank,
      cast( OrgPlnt.MaterialPlannedDeliveryDurn as abap.int2 ) as LeadTimeDays,

      @Semantics.amount.currencyCode: 'Currency'
      OrgPlnt.NetPriceAmount                                   as NetPrice,
      OrgPlnt.Currency                                         as Currency
}
where OrgPlnt.PurchasingInfoRecordCategory = '0'   -- fiche info standard
```

> **⚠️ Organisation d'achat par division**
> La jointure lit la ligne **par défaut** (division à blanc) de `ZTRESA_SRCDOCTY`. Si certaines divisions ont
> une organisation d'achat propre, compléter par une seconde jointure sur `DocType.werks = OrgPlnt.Plant` et
> un `coalesce`, sur le modèle du plafond en C4. Sans ce filtre, un fournisseur présent dans deux organisations
> d'achat apparaît deux fois sur la même clé.

---

### C2 — Stock, entrepôts et centres voisins

#### C2.1 `ZI_ResaPlantStock` — stock par division et article

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stock disponible par division et article'

-- ⚠️ R3 : vue de stock et champ de quantité à confirmer ; décision stock libre / ATP à prendre
--    (question ouverte n°2 du MO maquettes). Le filtre ci-dessous retient le stock libre utilisation.
define view entity ZI_ResaPlantStock
  as select from I_MaterialStock_2
{
  key Plant,
  key Material,
      @Semantics.quantity.unitOfMeasure: 'MaterialBaseUnit'
      sum( MatlWrhsStkQtyInMatlBaseUnit ) as StockQuantity,
      MaterialBaseUnit
}
where InventoryStockType        = '01'
  and InventorySpecialStockType = ''
group by
  Plant,
  Material,
  MaterialBaseUnit
```

#### C2.2 `ZI_ResaSrcWhse` — entrepôts

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Source d''appro - entrepôts'

define view entity ZI_ResaSrcWhse
  as select from    ztresa_whse       as Whse

    inner join      ZI_ResaPlantStock as Stock
      on Stock.Plant = Whse.whwerks

    left outer join I_Plant           as WhPlant
      on WhPlant.Plant = Whse.whwerks
{
  key Whse.werks                                    as Plant,
  key Stock.Material                                as Material,
  key cast( 'WHSE' as zresa_srctype )               as SourceType,
  key cast( Whse.whwerks as zresa_srcid )           as SourceId,

      cast( WhPlant.PlantName as abap.char(80) )    as SourceName,
      cast( Whse.srcrank as abap.int2 )             as SourceRank,
      Whse.leadtime                                 as LeadTimeDays,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Stock.StockQuantity                           as AvailableQuantity,
      Stock.MaterialBaseUnit                        as BaseUnit
}
where Stock.StockQuantity > 0
```

#### C2.3 `ZI_ResaSrcStore` — centres voisins

Identique à `ZI_ResaSrcWhse` en remplaçant :

| Élément | `ZI_ResaSrcWhse` | `ZI_ResaSrcStore` |
|---|---|---|
| Table | `ztresa_whse as Whse` | `ztresa_neighb as Neighb` |
| Division source | `Whse.whwerks` | `Neighb.nbwerks` |
| Type de source | `'WHSE'` | `'STOR'` |
| Libellé | `Source d''appro - entrepôts` | `Source d''appro - centres voisins` |

---

### C3 — Union des candidats : `ZI_ResaSrcCandidate`

Une ligne par **division × article × source**. Les colonnes absentes d'une famille sont typées à l'identique
dans chaque branche (exigence de l'union).

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sources candidates par division et article'

-- Point de concentration de la complexité : toute évolution des règles d'approvisionnement se fait ici
-- ou dans les vues de famille, sans impact sur le BO ni sur les écrans.
define view entity ZI_ResaSrcCandidate
  as select from ZI_ResaSrcEdi
{
  key Plant,
  key Material,
  key SourceType,
  key SourceId,
      SourceName,
      SupplierAvailability,
      SourceRank,
      LeadTimeDays,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      cast( 0 as abap.quan(13,3) )     as AvailableQuantity,
      cast( '' as meins )              as BaseUnit,
      @Semantics.amount.currencyCode: 'Currency'
      NetPrice,
      Currency
}

union all

select from ZI_ResaSrcWhse
{
  key Plant,
  key Material,
  key SourceType,
  key SourceId,
      SourceName,
      cast( '' as abap.char(1) )       as SupplierAvailability,
      SourceRank,
      LeadTimeDays,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      cast( AvailableQuantity as abap.quan(13,3) ) as AvailableQuantity,
      BaseUnit,
      @Semantics.amount.currencyCode: 'Currency'
      cast( 0 as abap.curr(11,2) )     as NetPrice,
      cast( '' as waers )              as Currency
}

union all

select from ZI_ResaSrcStore
{
  key Plant,
  key Material,
  key SourceType,
  key SourceId,
      SourceName,
      cast( '' as abap.char(1) )       as SupplierAvailability,
      SourceRank,
      LeadTimeDays,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      cast( AvailableQuantity as abap.quan(13,3) ) as AvailableQuantity,
      BaseUnit,
      @Semantics.amount.currencyCode: 'Currency'
      cast( 0 as abap.curr(11,2) )     as NetPrice,
      cast( '' as waers )              as Currency
}
```

> **⚠️ Types de l'union**
> Le type de `NetPrice` de la première branche fixe celui des suivantes : aligner `abap.curr(11,2)` sur le type
> réel de `NetPriceAmount` relevé en R2. Si l'union est refusée en view entity (R6), créer cette vue en vue
> classique avec `@AbapCatalog.sqlViewName: 'ZIRESASRCCAND'`.

---

### C4 — Options par poste de DA : `ZI_ResaSourceAvail`

Une ligne par **poste de DA ouvert × source**, plus une ligne `CASH` si le montant du poste est sous le plafond.

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sources d''approvisionnement disponibles par poste'

-- Aucune règle de priorité : SourceRank est restitué pour information, le choix reste manuel.
-- ⚠️ R1 : noms de champs de I_PurchaseRequisitionItem à confirmer ; ajouter les filtres de suppression
--    et de clôture du poste relevés.
define view entity ZI_ResaSourceAvail
  as select from I_PurchaseRequisitionItem as Item

    inner join   ZI_ResaSrcCandidate       as Cand
      on  Cand.Plant    = Item.Plant
      and Cand.Material = Item.Material
{
  key Item.PurchaseRequisition,
  key Item.PurchaseRequisitionItem,
  key Cand.SourceType,
  key Cand.SourceId,

      Item.Plant,
      Cand.SourceName,
      Cand.SourceRank,

      -- A : disponible · B : partiellement disponible · C : non disponible
      -- ⚠️ R5 : pour EDI, correspondance des codes ZC10 avec A / B / C à confirmer
      cast( case
              when Cand.SourceType = 'EDI'
                then Cand.SupplierAvailability
              when Cand.AvailableQuantity >= Item.RequestedQuantity
                then 'A'
              else 'B'
            end as abap.char(1) )                   as Availability,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Cand.AvailableQuantity,
      Cand.BaseUnit,
      Cand.LeadTimeDays,

      @Semantics.amount.currencyCode: 'Currency'
      Cand.NetPrice,
      Cand.Currency
}
where Item.PurchaseOrder = ''

union all

select from    I_PurchaseRequisitionItem as Item

  left outer join ztresa_pclimit         as PlantLimit
    on PlantLimit.werks = Item.Plant

  left outer join ztresa_pclimit         as DefaultLimit
    on DefaultLimit.werks = ''
{
  key Item.PurchaseRequisition,
  key Item.PurchaseRequisitionItem,
  key cast( 'CASH' as zresa_srctype )                  as SourceType,
  key cast( 'PETITECAIS' as zresa_srcid )              as SourceId,

      Item.Plant,
      cast( 'Achat local - petite caisse' as abap.char(80) ) as SourceName,
      cast( 99 as abap.int2 )                          as SourceRank,
      cast( 'A' as abap.char(1) )                      as Availability,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      cast( Item.RequestedQuantity as abap.quan(13,3) ) as AvailableQuantity,
      Item.BaseUnit,
      cast( 0 as abap.int2 )                           as LeadTimeDays,

      @Semantics.amount.currencyCode: 'Currency'
      cast( Item.PurchaseRequisitionPrice as abap.curr(11,2) ) as NetPrice,
      Item.Currency
}
where Item.PurchaseOrder = ''
  and Item.Currency      = coalesce( PlantLimit.waers, DefaultLimit.waers )
  and get_numeric_value( Item.PurchaseRequisitionPrice )
        * get_numeric_value( Item.RequestedQuantity )
        / ⟨CHAMP_UNITE_DE_PRIX_DA⟩
      <= get_numeric_value( coalesce( PlantLimit.maxamount, DefaultLimit.maxamount ) )
```

> **⚠️ Montant du poste**
> Le montant comparé au plafond est *prix × quantité / unité de prix*. Le nom du champ d'unité de prix de
> `I_PurchaseRequisitionItem` est à relever (R1). Si `get_numeric_value` n'est pas disponible (R6), effectuer ce
> calcul dans une vue classique intermédiaire où le `cast` de `CURR` vers `DEC` est admis. Un poste dont la
> devise diffère de celle du plafond **n'est pas éligible** : c'est une règle, pas une limite technique.

> **ℹ️ Identifiant `PETITECAIS`**
> `ZRESA_SRCID` fait 10 caractères : l'identifiant de la maquette `PETITECAISSE` (12) est tronqué.

---

### C5 — Nombre de sources par poste : `ZI_ResaSourceCount`

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Nombre de sources candidates par poste'

define view entity ZI_ResaSourceCount
  as select from ZI_ResaSourceAvail
{
  key PurchaseRequisition,
  key PurchaseRequisitionItem,
      count( * )                                                  as SourceOptionCount,
      sum( case when SourceType = 'EDI'  then 1 else 0 end )      as SupplierSourceCount,
      max( case when SourceType = 'CASH' then 'X' else '' end )   as PettyCashEligible
}
group by
  PurchaseRequisition,
  PurchaseRequisitionItem
```

---

### C6 — Aides à la saisie

| Vue | Base | Usage |
|---|---|---|
| `ZI_ResaSourceTypeVH` | `DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZRESA_SRCTYPE' )`, filtrée sur la langue de session | Type de source (filtres, paramètre d'action) |
| `ZI_ResaPlantVH` | `I_Plant` (division, nom) | Division |
| `ZI_ResaSrcCandidateVH` | `ZI_ResaSrcCandidate` (division, article, type, identifiant, nom, délai) | Source à la saisie (Alternative 2) |

Modèle, à décliner pour chaque vue :

```abap
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Aide à la saisie - source candidate'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.representativeKey: 'SourceId'
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
@Search.searchable: true

define view entity ZI_ResaSrcCandidateVH
  as select from ZI_ResaSrcCandidate
{
      @UI.hidden: true
  key Plant,
      @UI.hidden: true
  key Material,
  key SourceType,
      @Search.defaultSearchElement: true
  key SourceId,
      @Search.defaultSearchElement: true
      SourceName,
      LeadTimeDays
}
```

> **⚠️ À vérifier** — `DDCDS_CUSTOMER_DOMAIN_VALUE_T` : relever dans ADT le nom exact des paramètres et des
> champs (valeur, langue, libellé) avant de créer `ZI_ResaSourceTypeVH`.

---

### C7 — Contrôle d'accès

Les vues d'interface ci-dessus sont `#NOT_REQUIRED` : elles ne sont jamais exposées directement. Le contrôle
d'accès est porté par les vues du BO (D1, DCL en D6) et hérité par les projections (F4).

### C8 — Ordre d'activation

1. `ZI_ResaSrcEdi` — 2. `ZI_ResaPlantStock` — 3. `ZI_ResaSrcWhse` — 4. `ZI_ResaSrcStore` —
5. `ZI_ResaSrcCandidate` — 6. `ZI_ResaSourceAvail` — 7. `ZI_ResaSourceCount` — 8. les trois aides à la saisie.

> **📸 COPIE D'ÉCRAN N°08** — ADT : aperçu de `ZI_ResaSrcCandidate` pour un article connu, les trois familles présentes
> *Remplacer cette ligne par :* `![Copie 08](images/RESA-SRC-RAP/capture-08.png)`

> **📸 COPIE D'ÉCRAN N°09** — ADT : aperçu de `ZI_ResaSourceAvail` pour un poste, avec la ligne `CASH`
> *Remplacer cette ligne par :* `![Copie 09](images/RESA-SRC-RAP/capture-09.png)`

#### Critères de validation de la partie C

- Pour un article et une division de test, chaque famille de source attendue apparaît, et une seule fois.
- Un poste sous le plafond porte une ligne `CASH` ; un poste au-dessus n'en porte pas.
- `ZI_ResaSourceCount` est cohérent avec un comptage manuel de `ZI_ResaSourceAvail`.

---

## Partie D — Business objects RAP

### D1 — Racine : `ZR_ResaPurReqSource`

Un poste de DA par ligne, enrichi du choix de source, du document aval et du nombre de sources.

```abap
@AccessControl.authorizationCheck: #CHECK
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'BO - Source d''appro par poste de DA'

-- ⚠️ R1 : noms de champs de I_PurchaseRequisitionItem à confirmer ; ajouter les filtres de suppression
--    et de clôture relevés. Aucun filtre sur PurchaseOrder ici : un poste converti doit rester lisible
--    par le BO pour que l'action retourne son résultat. Le filtre « à traiter » est posé par l'écran.
define root view entity ZR_ResaPurReqSource
  as select from    I_PurchaseRequisitionItem as Item

    left outer join ztresa_srcsel             as Sel
      on  Sel.banfn = Item.PurchaseRequisition
      and Sel.bnfpo = Item.PurchaseRequisitionItem

    left outer join ztresa_pcorder            as Pc
      on  Pc.banfn = Item.PurchaseRequisition
      and Pc.bnfpo = Item.PurchaseRequisitionItem

    left outer join ZI_ResaSourceCount        as Cnt
      on  Cnt.PurchaseRequisition     = Item.PurchaseRequisition
      and Cnt.PurchaseRequisitionItem = Item.PurchaseRequisitionItem

  composition [0..*] of ZR_ResaSourceOption as _SourceOption
  composition [0..*] of ZR_ResaPettyCash    as _PettyCash
{
  key Item.PurchaseRequisition,
  key Item.PurchaseRequisitionItem,

      -- origine
      Item.ZZReservation                                          as Reservation,
      cast( case when Item.ZZReservation <> '' then 'RESA'
                 when Item.SalesOrder    <> '' then 'VENT'
                 else                               'AUTR'
            end as abap.char(4) )                                 as OriginType,

      -- besoin
      Item.Plant,
      Item.PurchasingGroup,
      Item.Material,
      Item.PurchaseRequisitionItemText,
      Item.DeliveryDate,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Item.RequestedQuantity,
      Item.BaseUnit,
      @Semantics.amount.currencyCode: 'Currency'
      Item.PurchaseRequisitionPrice                               as ItemPrice,
      Item.Currency,

      -- document aval
      Item.PurchaseOrder,
      Item.PurchaseOrderItem,
      Pc.pcnum                                                    as PettyCashOrder,
      cast( coalesce( nullif( Item.PurchaseOrder, '' ), Pc.pcnum )
            as abap.char(10) )                                    as FollowOnDocument,

      -- choix de source (persisté dans ZTRESA_SRCSEL)
      Sel.srctype                                                 as SelectedSourceType,
      Sel.srcid                                                   as SelectedSourceId,
      Sel.bsart                                                   as SelectedDocType,
      Sel.status                                                  as ProcessStatus,
      Sel.msgtxt                                                  as StatusMessage,

      -- statut calculé affiché
      cast( case when Item.PurchaseOrder <> ''                     then 'CONV'
                 when Pc.pcnum is not null                         then 'CONV'
                 when Sel.status is not null and Sel.status <> ''  then Sel.status
                 else                                                   'TODO'
            end as zresa_procstat )                               as SourceStatus,

      case when Item.PurchaseOrder <> '' or Pc.pcnum is not null   then 3
           when Sel.status = 'ERR'                                 then 1
           when Sel.status is not null and Sel.status <> ''        then 2
           else                                                         0
      end                                                         as SourceCriticality,

      -- comparatif
      coalesce( Cnt.SourceOptionCount, 0 )                        as SourceOptionCount,
      coalesce( Cnt.SupplierSourceCount, 0 )                      as SupplierSourceCount,
      cast( coalesce( Cnt.PettyCashEligible, '' ) as abap.char(1) ) as PettyCashEligible,

      -- administration
      @Semantics.user.createdBy: true
      Sel.created_by                                              as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      Sel.created_at                                              as CreatedAt,
      @Semantics.user.lastChangedBy: true
      Sel.last_changed_by                                         as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      Sel.last_changed_at                                         as LastChangedAt,

      _SourceOption,
      _PettyCash
}
```

> **⚠️ Une seule commande petite caisse par poste**
> La jointure sur `ZTRESA_PCORDER` suppose au plus un document par poste. C'est garanti par le contrôle des
> fonctionnalités (E2) : l'action est désactivée dès qu'un document aval existe.

> **ℹ️ `nullif` / `coalesce`**
> Si `nullif` est refusé, remplacer par
> `case when Item.PurchaseOrder <> '' then Item.PurchaseOrder else Pc.pcnum end`.

---

### D2 — Enfant lecture seule : `ZR_ResaSourceOption`

```abap
@AccessControl.authorizationCheck: #CHECK
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'BO - Option de source d''un poste'

define view entity ZR_ResaSourceOption
  as select from    ZI_ResaSourceAvail as Src

    left outer join ztresa_srcsel      as Sel
      on  Sel.banfn = Src.PurchaseRequisition
      and Sel.bnfpo = Src.PurchaseRequisitionItem

  association to parent ZR_ResaPurReqSource as _Item
    on  $projection.PurchaseRequisition     = _Item.PurchaseRequisition
    and $projection.PurchaseRequisitionItem = _Item.PurchaseRequisitionItem
{
  key Src.PurchaseRequisition,
  key Src.PurchaseRequisitionItem,
  key Src.SourceType,
  key Src.SourceId,

      Src.Plant,
      Src.SourceName,
      Src.SourceRank,
      Src.Availability,

      case Src.Availability
        when 'A' then 3
        when 'B' then 2
        else          1
      end                                                   as AvailabilityCriticality,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Src.AvailableQuantity,
      Src.BaseUnit,
      Src.LeadTimeDays,

      @Semantics.amount.currencyCode: 'Currency'
      Src.NetPrice,
      Src.Currency,

      cast( case when Sel.srctype = Src.SourceType
                  and Sel.srcid   = Src.SourceId
                 then 'X' else '' end as abap_boolean )     as IsSelected,

      _Item
}
```

---

### D3 — Enfant petite caisse : `ZR_ResaPettyCash`

```abap
@AccessControl.authorizationCheck: #CHECK
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'BO - Commande petite caisse'

define view entity ZR_ResaPettyCash
  as select from ztresa_pcorder as Pc

  association to parent ZR_ResaPurReqSource as _Item
    on  $projection.PurchaseRequisition     = _Item.PurchaseRequisition
    and $projection.PurchaseRequisitionItem = _Item.PurchaseRequisitionItem
{
  key Pc.banfn    as PurchaseRequisition,
  key Pc.bnfpo    as PurchaseRequisitionItem,
  key Pc.pcnum    as PettyCashOrder,

      Pc.resnum   as Reservation,
      Pc.werks    as Plant,
      Pc.matnr    as Material,
      Pc.txz01    as ItemText,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Pc.menge    as Quantity,
      Pc.meins    as BaseUnit,
      @Semantics.amount.currencyCode: 'Currency'
      Pc.netwr    as Amount,
      Pc.waers    as Currency,
      Pc.lifname  as LocalSupplierName,
      Pc.status   as PettyCashStatus,
      Pc.erdat    as CreationDate,
      Pc.ernam    as CreatedByUser,

      _Item
}
```

---

### D4 — BO de création : `ZR_ResaReplenRequest`

```abap
@AccessControl.authorizationCheck: #CHECK
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'BO - Besoin de réapprovisionnement saisi'

define root view entity ZR_ResaReplenRequest
  as select from ztresa_replreq as Req
{
  key Req.req_uuid    as RequestUuid,
      Req.reqtype     as RequestType,
      Req.werks       as Plant,
      Req.matnr       as Material,
      Req.txz01       as ItemText,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Req.menge       as Quantity,
      Req.meins       as BaseUnit,
      Req.lfdat       as DeliveryDate,
      Req.srctype     as SourceType,
      Req.srcid       as SourceId,
      Req.bsart       as DocType,
      Req.status      as ProcessStatus,
      case Req.status
        when 'CONV' then 3
        when 'ERR'  then 1
        else             2
      end             as StatusCriticality,
      Req.banfn       as PurchaseRequisition,
      Req.ebeln       as PurchaseOrder,
      Req.msgtxt      as StatusMessage,
      @Semantics.user.createdBy: true
      Req.created_by  as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      Req.created_at  as CreatedAt
}
```

---

### D5 — Entités abstraites (paramètres d'action)

#### D5.1 `ZD_ResaPettyCashParam`

```abap
@EndUserText.label: 'Paramètres - commande petite caisse'
define abstract entity ZD_ResaPettyCashParam
{
  @EndUserText.label: 'Fournisseur local'
  LocalSupplierName : abap.char(80);

  @EndUserText.label: 'Montant'
  @Semantics.amount.currencyCode: 'Currency'
  Amount            : abap.curr(13,2);

  @EndUserText.label: 'Devise'
  Currency          : waers;
}
```

#### D5.2 `ZD_ResaReplenPRParam` (Alternative 1)

```abap
@EndUserText.label: 'Paramètres - création d''une demande d''achat'
define abstract entity ZD_ResaReplenPRParam
{
  @EndUserText.label: 'Division'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ResaPlantVH', element: 'Plant' } }]
  Plant        : werks_d;

  @EndUserText.label: 'Article'
  Material     : matnr;

  @EndUserText.label: 'Désignation'
  ItemText     : txz01;

  @EndUserText.label: 'Quantité'
  @Semantics.quantity.unitOfMeasure: 'BaseUnit'
  Quantity     : menge_d;

  @EndUserText.label: 'Unité'
  BaseUnit     : meins;

  @EndUserText.label: 'Date de besoin'
  DeliveryDate : eindt;
}
```

#### D5.3 `ZD_ResaReplenPOParam` (Alternative 2)

Mêmes éléments que `ZD_ResaReplenPRParam`, **plus** :

```abap
  @EndUserText.label: 'Type de source'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ResaSourceTypeVH', element: 'SourceType' } }]
  SourceType   : zresa_srctype;

  @EndUserText.label: 'Source'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ResaSrcCandidateVH', element: 'SourceId' },
                                       additionalBinding: [ { localElement: 'Plant',      element: 'Plant' },
                                                            { localElement: 'Material',   element: 'Material' },
                                                            { localElement: 'SourceType', element: 'SourceType' } ] }]
  SourceId     : zresa_srcid;
```

> **⚠️ À contrôler en recette (J1, point 22)** — le filtrage de l'aide à la saisie de `SourceId` par les autres
> paramètres du dialogue d'action. S'il n'est pas appliqué par Fiori elements 1.96, la validation de l'action
> (E5) rejette de toute façon une source non candidate : le contrôle métier ne dépend pas de l'écran.

---

### D6 — Contrôle d'accès des vues du BO

`ZR_ResaPurReqSource` (même modèle pour `ZR_ResaSourceOption` et `ZR_ResaPettyCash`, qui portent `Plant`) :

```abap
@EndUserText.label: 'Accès aux postes de DA par division'
@MappingRole: true
define role ZR_ResaPurReqSource {
  grant select on ZR_ResaPurReqSource
    where ( Plant ) = aspect pfcg_auth( M_BANF_WRK, WERKS, ACTVT = '03' );
}
```

`ZR_ResaReplenRequest` :

```abap
@EndUserText.label: 'Accès aux besoins de réappro par division'
@MappingRole: true
define role ZR_ResaReplenRequest {
  grant select on ZR_ResaReplenRequest
    where ( Plant ) = aspect pfcg_auth( M_BANF_WRK, WERKS, ACTVT = '03' );
}
```

---

### D7 — Behavior definition : `ZR_ResaPurReqSource`

ADT → clic droit sur `ZR_ResaPurReqSource` → *New Behavior Definition*, type d'implémentation **Managed**,
puis adapter comme suit.

```abap
managed with unmanaged save implementation in class zbp_r_resapurreqsource unique;
strict;

define behavior for ZR_ResaPurReqSource alias PurReqSource
lock master unmanaged
authorization master ( instance )
{
  // mise à jour interne uniquement (actions en LOCAL MODE) : non exposée dans les projections
  update;

  association _SourceOption;
  association _PettyCash { create ( features : instance ); }

  field ( readonly )
    PurchaseRequisition, PurchaseRequisitionItem, Reservation, OriginType,
    Plant, PurchasingGroup, Material, PurchaseRequisitionItemText, DeliveryDate,
    RequestedQuantity, BaseUnit, ItemPrice, Currency,
    PurchaseOrder, PurchaseOrderItem, PettyCashOrder, FollowOnDocument,
    SelectedSourceType, SelectedSourceId, SelectedDocType, ProcessStatus, StatusMessage,
    SourceStatus, SourceCriticality, SourceOptionCount, SupplierSourceCount, PettyCashEligible,
    CreatedBy, CreatedAt, LastChangedBy, LastChangedAt;

  action ( features : instance ) ConvertToPurchaseOrder result [1] $self;
  action ( features : instance ) CreatePettyCashOrder
    parameter ZD_ResaPettyCashParam result [1] $self;

  mapping for ztresa_srcsel corresponding
  {
    PurchaseRequisition     = banfn;
    PurchaseRequisitionItem = bnfpo;
    SelectedSourceType      = srctype;
    SelectedSourceId        = srcid;
    SelectedDocType         = bsart;
    ProcessStatus           = status;
    StatusMessage           = msgtxt;
    CreatedBy               = created_by;
    CreatedAt               = created_at;
    LastChangedBy           = last_changed_by;
    LastChangedAt           = last_changed_at;
  }
}

define behavior for ZR_ResaSourceOption alias SourceOption
lock dependent by _Item
authorization dependent by _Item
{
  association _Item;

  action ( features : instance ) SelectSource result [1] $self;
}

define behavior for ZR_ResaPettyCash alias PettyCash
late numbering
lock dependent by _Item
authorization dependent by _Item
{
  association _Item;

  field ( readonly )
    PurchaseRequisition, PurchaseRequisitionItem, PettyCashOrder,
    Reservation, Plant, Material, ItemText, Quantity, BaseUnit,
    Amount, Currency, LocalSupplierName, PettyCashStatus, CreationDate, CreatedByUser;

  mapping for ztresa_pcorder corresponding
  {
    PurchaseRequisition     = banfn;
    PurchaseRequisitionItem = bnfpo;
    PettyCashOrder          = pcnum;
    Reservation             = resnum;
    Plant                   = werks;
    Material                = matnr;
    ItemText                = txz01;
    Quantity                = menge;
    BaseUnit                = meins;
    Amount                  = netwr;
    Currency                = waers;
    LocalSupplierName       = lifname;
    PettyCashStatus         = status;
    CreationDate            = erdat;
    CreatedByUser           = ernam;
  }
}
```

| Élément | Justification |
|---|---|
| `lock master unmanaged` | Le verrou est **celui de la DA standard** (R4) : protège aussi contre ME59N ou une modification ME52N simultanée |
| `authorization master ( instance )` | Contrôles par division et type de document (E3) |
| `update` sans exposition | Les champs `readonly` sont modifiés **uniquement** par les actions, en `IN LOCAL MODE` |
| `features : instance` | Boutons actifs selon le statut du poste (E2) |
| Pas de `etag master` | Sans draft et avec verrou pessimiste sur la DA ; un ETag sur un champ d'une ligne pas encore créée n'apporterait rien |
| Pas de validation `on save` | Les actions sont les **seuls** points d'entrée : les contrôles y sont faits et bloquent immédiatement, avec message à l'utilisateur |
| `late numbering` sur `PettyCash` | Numéro SNRO attribué en sauvegarde, sans trou en cas d'abandon |

> **📸 COPIE D'ÉCRAN N°10** — ADT : behavior definition `ZR_ResaPurReqSource` activée
> *Remplacer cette ligne par :* `![Copie 10](images/RESA-SRC-RAP/capture-10.png)`

---

### D8 — Behavior definition : `ZR_ResaReplenRequest`

```abap
managed with unmanaged save implementation in class zbp_r_resareplenrequest unique;
strict;

define behavior for ZR_ResaReplenRequest alias ReplenRequest
lock master unmanaged
authorization master ( global )
{
  // création interne uniquement, par les actions statiques
  create;

  field ( numbering : managed, readonly ) RequestUuid;
  field ( readonly )
    RequestType, Plant, Material, ItemText, Quantity, BaseUnit, DeliveryDate,
    SourceType, SourceId, DocType, ProcessStatus, StatusCriticality,
    PurchaseRequisition, PurchaseOrder, StatusMessage, CreatedBy, CreatedAt;

  static action CreatePurchaseRequisition
    parameter ZD_ResaReplenPRParam result [1] $self;
  static action CreateReplenishmentOrder
    parameter ZD_ResaReplenPOParam result [1] $self;

  mapping for ztresa_replreq corresponding
  {
    RequestUuid         = req_uuid;
    RequestType         = reqtype;
    Plant               = werks;
    Material            = matnr;
    ItemText            = txz01;
    Quantity            = menge;
    BaseUnit            = meins;
    DeliveryDate        = lfdat;
    SourceType          = srctype;
    SourceId            = srcid;
    DocType             = bsart;
    ProcessStatus       = status;
    PurchaseRequisition = banfn;
    PurchaseOrder       = ebeln;
    StatusMessage       = msgtxt;
    CreatedBy           = created_by;
    CreatedAt           = created_at;
  }
}
```

> **ℹ️ Pourquoi l'Alternative 2 ne crée pas de DA**
> Une DA créée par `BAPI_PR_CREATE` n'est pas encore en base au moment où `BAPI_PO_CREATE1` s'exécute dans la
> même unité de travail : la commande ne peut pas la référencer. Le besoin saisi est tracé par
> `ZTRESA_REPLREQ` (numéro de commande, source, statut), la commande est créée directement.

> **ℹ️ `lock master unmanaged` sur un BO de création**
> Une instance n'est jamais modifiée après création : la méthode de verrouillage est vide (E6).

---

## Partie E — Implémentation ABAP

ADT → dans la behavior definition, *Quick Fix* (Ctrl+1) sur la ligne `implementation in class` → *Create
behavior implementation class*. Le squelette généré contient un gestionnaire local par entité (`lhc_…`) et une
classe de sauvegarde (`lsc_…`). Les étapes ci-dessous en donnent le contenu.

> **⚠️ Instructions interdites**
> Dans les gestionnaires (phase d'interaction) : aucune mise à jour de base, aucun appel de BAPI qui écrit.
> Dans toute la classe : jamais `COMMIT WORK`, `ROLLBACK WORK`, `BAPI_TRANSACTION_COMMIT`,
> `BAPI_TRANSACTION_ROLLBACK`. C'est le framework RAP qui clôt l'unité de travail.

### E1 — Verrouillage

```abap
CLASS lhc_PurReqSource DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK PurReqSource.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR PurReqSource RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR PurReqSource RESULT result.

    METHODS ConvertToPurchaseOrder FOR MODIFY
      IMPORTING keys FOR ACTION PurReqSource~ConvertToPurchaseOrder RESULT result.

    METHODS CreatePettyCashOrder FOR MODIFY
      IMPORTING keys FOR ACTION PurReqSource~CreatePettyCashOrder RESULT result.
ENDCLASS.

CLASS lhc_PurReqSource IMPLEMENTATION.

  METHOD lock.
    " ⚠️ R4 : nom de l'objet de verrouillage de EBAN et de ses paramètres à confirmer en SE11
    LOOP AT keys INTO DATA(ls_key).
      CALL FUNCTION 'ENQUEUE_⟨OBJET_VERROU_EBAN⟩'
        EXPORTING
          banfn          = ls_key-PurchaseRequisition
          bnfpo          = ls_key-PurchaseRequisitionItem
        EXCEPTIONS
          foreign_lock   = 1
          system_failure = 2
          OTHERS         = 3.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-purreqsource.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message( id       = 'ZRESA_SRC'
                                            number   = '001'
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = ls_key-PurchaseRequisition
                                            v2       = ls_key-PurchaseRequisitionItem
                                            v3       = sy-msgv1 ) )
               TO reported-purreqsource.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
```

> **ℹ️ Déverrouillage**
> Le module `ENQUEUE_…` généré a par défaut la portée `_SCOPE = '2'` : le verrou est libéré à la fin de l'unité
> de travail, que la sauvegarde aboutisse ou non. Aucun `DEQUEUE` n'est à coder.

---

### E2 — Contrôle des fonctionnalités

| Action | Active si |
|---|---|
| `SelectSource` (option) | Poste sans document aval **et** option non déjà retenue |
| `ConvertToPurchaseOrder` | Poste sans document aval **et** source retenue **et** source ≠ `CASH` |
| `CreatePettyCashOrder` / création `_PettyCash` | Poste sans document aval **et** `PettyCashEligible = 'X'` |

```abap
  METHOD get_instance_features.
    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY PurReqSource
        FIELDS ( FollowOnDocument SelectedSourceType PettyCashEligible )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    result = VALUE #( FOR ls_item IN lt_item
      LET lv_open = xsdbool( ls_item-FollowOnDocument IS INITIAL )
          lv_conv = COND #( WHEN lv_open = abap_true
                             AND ls_item-SelectedSourceType IS NOT INITIAL
                             AND ls_item-SelectedSourceType <> 'CASH'
                            THEN if_abap_behv=>fc-o-enabled
                            ELSE if_abap_behv=>fc-o-disabled )
          lv_pc   = COND #( WHEN lv_open = abap_true
                             AND ls_item-PettyCashEligible = abap_true
                            THEN if_abap_behv=>fc-o-enabled
                            ELSE if_abap_behv=>fc-o-disabled )
      IN ( %tky                           = ls_item-%tky
           %action-ConvertToPurchaseOrder = lv_conv
           %action-CreatePettyCashOrder   = lv_pc
           %assoc-_PettyCash              = lv_pc ) ).
  ENDMETHOD.
```

---

### E3 — Autorisations d'instance

| Opération | Objet | Champs |
|---|---|---|
| Mise à jour (donc `SelectSource`, dépendant) | `M_BANF_WRK` | `ACTVT = 02`, `WERKS` = division |
| `ConvertToPurchaseOrder` | `M_BEST_WRK` et `M_BEST_BSA` | `ACTVT = 01`, `WERKS` ; `ACTVT = 01`, `BSART` = type retenu |
| `CreatePettyCashOrder` | `ZRESA_PC` (I1) | `ACTVT = 01`, `WERKS` |

```abap
  METHOD get_instance_authorizations.
    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY PurReqSource
        FIELDS ( Plant SelectedDocType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    LOOP AT lt_item INTO DATA(ls_item).
      DATA(lv_upd)  = if_abap_behv=>auth-unauthorized.
      DATA(lv_conv) = if_abap_behv=>auth-unauthorized.
      DATA(lv_pc)   = if_abap_behv=>auth-unauthorized.

      IF requested_authorizations-%update = if_abap_behv=>mk-on.
        AUTHORITY-CHECK OBJECT 'M_BANF_WRK'
          ID 'ACTVT' FIELD '02'
          ID 'WERKS' FIELD ls_item-Plant.
        IF sy-subrc = 0.
          lv_upd = if_abap_behv=>auth-allowed.
        ENDIF.
      ENDIF.

      IF requested_authorizations-%action-ConvertToPurchaseOrder = if_abap_behv=>mk-on.
        AUTHORITY-CHECK OBJECT 'M_BEST_WRK'
          ID 'ACTVT' FIELD '01'
          ID 'WERKS' FIELD ls_item-Plant.
        IF sy-subrc = 0.
          " type de document encore inconnu : contrôle refait dans l'action (E5)
          IF ls_item-SelectedDocType IS INITIAL.
            lv_conv = if_abap_behv=>auth-allowed.
          ELSE.
            AUTHORITY-CHECK OBJECT 'M_BEST_BSA'
              ID 'ACTVT' FIELD '01'
              ID 'BSART' FIELD ls_item-SelectedDocType.
            IF sy-subrc = 0.
              lv_conv = if_abap_behv=>auth-allowed.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.

      IF requested_authorizations-%action-CreatePettyCashOrder = if_abap_behv=>mk-on.
        AUTHORITY-CHECK OBJECT 'ZRESA_PC'
          ID 'ACTVT' FIELD '01'
          ID 'WERKS' FIELD ls_item-Plant.
        IF sy-subrc = 0.
          lv_pc = if_abap_behv=>auth-allowed.
        ENDIF.
      ENDIF.

      APPEND VALUE #( %tky                           = ls_item-%tky
                      %update                        = lv_upd
                      %action-ConvertToPurchaseOrder = lv_conv
                      %action-CreatePettyCashOrder   = lv_pc )
             TO result.
    ENDLOOP.
  ENDMETHOD.
```

> **ℹ️ Actions en `IN LOCAL MODE`**
> Le contrôle des fonctionnalités et des autorisations n'est **pas** rejoué pour les opérations lancées en local
> par l'implémentation elle-même : c'est ce qui permet à `SelectSource` de mettre à jour la racine, et c'est
> pourquoi chaque action refait explicitement ses contrôles métier.

---

### E4 — Classe utilitaire de customizing : `ZCL_RESA_SRC_CUSTO`

Classe globale (ADT → *New ABAP Class*), méthodes statiques, lecture avec repli sur la division à blanc.

```abap
CLASS zcl_resa_src_custo DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS get_doc_type
      IMPORTING iv_plant         TYPE werks_d
                iv_srctype       TYPE zresa_srctype
      RETURNING VALUE(rs_doctype) TYPE ztresa_srcdocty.

    CLASS-METHODS get_repl_cfg
      IMPORTING iv_plant      TYPE werks_d
      RETURNING VALUE(rs_cfg) TYPE ztresa_replcfg.

    CLASS-METHODS get_pc_limit
      IMPORTING iv_plant        TYPE werks_d
      RETURNING VALUE(rs_limit) TYPE ztresa_pclimit.
ENDCLASS.

CLASS zcl_resa_src_custo IMPLEMENTATION.

  METHOD get_doc_type.
    SELECT SINGLE * FROM ztresa_srcdocty
      WHERE werks = @iv_plant AND srctype = @iv_srctype
      INTO @rs_doctype.
    IF sy-subrc <> 0.
      SELECT SINGLE * FROM ztresa_srcdocty
        WHERE werks = '' AND srctype = @iv_srctype
        INTO @rs_doctype.
    ENDIF.
  ENDMETHOD.

  METHOD get_repl_cfg.
    SELECT SINGLE * FROM ztresa_replcfg WHERE werks = @iv_plant INTO @rs_cfg.
    IF sy-subrc <> 0.
      SELECT SINGLE * FROM ztresa_replcfg WHERE werks = '' INTO @rs_cfg.
    ENDIF.
  ENDMETHOD.

  METHOD get_pc_limit.
    SELECT SINGLE * FROM ztresa_pclimit WHERE werks = @iv_plant INTO @rs_limit.
    IF sy-subrc <> 0.
      SELECT SINGLE * FROM ztresa_pclimit WHERE werks = '' INTO @rs_limit.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
```

---

### E5 — Actions du BO de détermination

#### E5.1 `SelectSource` (gestionnaire de l'option)

```abap
CLASS lhc_SourceOption DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR SourceOption RESULT result.

    METHODS SelectSource FOR MODIFY
      IMPORTING keys FOR ACTION SourceOption~SelectSource RESULT result.
ENDCLASS.

CLASS lhc_SourceOption IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY SourceOption
        FIELDS ( IsSelected ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_opt)
      ENTITY SourceOption BY \_Item
        FIELDS ( FollowOnDocument ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_opt INTO DATA(ls_opt).
      DATA(ls_item) = VALUE #( lt_item[ PurchaseRequisition     = ls_opt-PurchaseRequisition
                                        PurchaseRequisitionItem = ls_opt-PurchaseRequisitionItem ] OPTIONAL ).
      APPEND VALUE #( %tky                 = ls_opt-%tky
                      %action-SelectSource = COND #( WHEN ls_item-FollowOnDocument IS INITIAL
                                                      AND ls_opt-IsSelected = abap_false
                                                     THEN if_abap_behv=>fc-o-enabled
                                                     ELSE if_abap_behv=>fc-o-disabled ) )
             TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD SelectSource.
    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY SourceOption ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_opt).

    LOOP AT lt_opt INTO DATA(ls_opt).
      DATA(ls_doc) = zcl_resa_src_custo=>get_doc_type( iv_plant   = ls_opt-Plant
                                                       iv_srctype = ls_opt-SourceType ).
      IF ls_opt-SourceType <> 'CASH' AND ls_doc-bsart IS INITIAL.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-sourceoption.
        APPEND VALUE #( %tky = ls_opt-%tky
                        %msg = new_message( id = 'ZRESA_SRC' number = '002'
                                            severity = if_abap_behv_message=>severity-error
                                            v1 = ls_opt-SourceType v2 = ls_opt-Plant ) )
               TO reported-sourceoption.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zr_resapurreqsource IN LOCAL MODE
        ENTITY PurReqSource
          UPDATE FIELDS ( SelectedSourceType SelectedSourceId SelectedDocType
                          ProcessStatus StatusMessage )
          WITH VALUE #( ( PurchaseRequisition     = ls_opt-PurchaseRequisition
                          PurchaseRequisitionItem = ls_opt-PurchaseRequisitionItem
                          SelectedSourceType      = ls_opt-SourceType
                          SelectedSourceId        = ls_opt-SourceId
                          SelectedDocType         = ls_doc-bsart
                          ProcessStatus           = 'SEL'
                          StatusMessage           = '' ) )
        FAILED   DATA(ls_failed)
        REPORTED DATA(ls_reported).

      IF ls_failed IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-sourceoption.
      ENDIF.
    ENDLOOP.

    result = VALUE #( FOR ls_res IN lt_opt ( %tky   = ls_res-%tky
                                              %param = CORRESPONDING #( ls_res ) ) ).
  ENDMETHOD.

ENDCLASS.
```

#### E5.2 `ConvertToPurchaseOrder`

L'action **ne crée pas** la commande : elle contrôle et positionne `ProcessStatus = 'REQ'`. La création a lieu
en sauvegarde (E5.4), dans la même requête HTTP.

```abap
  METHOD ConvertToPurchaseOrder.
    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY PurReqSource ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    LOOP AT lt_item INTO DATA(ls_item).
      DATA(lv_msgno) = CONV symsgno( '' ).

      IF ls_item-FollowOnDocument IS NOT INITIAL.
        lv_msgno = '007'.
      ELSEIF ls_item-SelectedSourceType IS INITIAL.
        lv_msgno = '003'.
      ELSEIF ls_item-SelectedSourceType = 'CASH'.
        lv_msgno = '004'.
      ELSEIF ls_item-SelectedDocType IS INITIAL.
        lv_msgno = '002'.
      ELSE.
        AUTHORITY-CHECK OBJECT 'M_BEST_BSA'
          ID 'ACTVT' FIELD '01'
          ID 'BSART' FIELD ls_item-SelectedDocType.
        IF sy-subrc <> 0.
          lv_msgno = '005'.
        ENDIF.
      ENDIF.

      IF lv_msgno IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-purreqsource.
        APPEND VALUE #( %tky = ls_item-%tky
                        %msg = new_message( id = 'ZRESA_SRC' number = lv_msgno
                                            severity = if_abap_behv_message=>severity-error
                                            v1 = SWITCH #( lv_msgno WHEN '002' THEN ls_item-SelectedSourceType
                                                                    WHEN '005' THEN ls_item-SelectedDocType
                                                                    ELSE ls_item-PurchaseRequisition )
                                            v2 = SWITCH #( lv_msgno WHEN '002' THEN ls_item-Plant
                                                                    ELSE ls_item-PurchaseRequisitionItem )
                                            v3 = ls_item-FollowOnDocument ) )
               TO reported-purreqsource.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zr_resapurreqsource IN LOCAL MODE
        ENTITY PurReqSource
          UPDATE FIELDS ( ProcessStatus StatusMessage )
          WITH VALUE #( ( %tky = ls_item-%tky ProcessStatus = 'REQ' StatusMessage = '' ) ).
    ENDLOOP.

    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY PurReqSource ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = ls_res ) ).
  ENDMETHOD.
```

#### E5.3 `CreatePettyCashOrder`

```abap
  METHOD CreatePettyCashOrder.
    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY PurReqSource ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_item)  = lt_item[ KEY entity %tky = ls_key-%tky ].
      DATA(ls_limit) = zcl_resa_src_custo=>get_pc_limit( ls_item-Plant ).
      DATA(lv_msgno) = CONV symsgno( '' ).

      IF ls_item-FollowOnDocument IS NOT INITIAL.
        lv_msgno = '007'.
      ELSEIF ls_limit IS INITIAL.
        lv_msgno = '009'.
      ELSEIF ls_key-%param-LocalSupplierName IS INITIAL.
        lv_msgno = '010'.
      ELSEIF ls_key-%param-Amount <= 0.
        lv_msgno = '011'.
      ELSEIF ls_key-%param-Currency <> ls_limit-waers.
        lv_msgno = '018'.
      ELSEIF ls_key-%param-Amount > ls_limit-maxamount.
        lv_msgno = '008'.
      ENDIF.

      IF lv_msgno IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-purreqsource.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message( id = 'ZRESA_SRC' number = lv_msgno
                                            severity = if_abap_behv_message=>severity-error
                                            v1 = SWITCH #( lv_msgno
                                                   WHEN '008' THEN |{ ls_key-%param-Amount } { ls_key-%param-Currency }|
                                                   WHEN '018' THEN ls_key-%param-Currency
                                                   WHEN '009' THEN ls_item-Plant
                                                   ELSE ls_item-PurchaseRequisition )
                                            v2 = SWITCH #( lv_msgno
                                                   WHEN '008' THEN |{ ls_limit-maxamount } { ls_limit-waers }|
                                                   WHEN '018' THEN ls_limit-waers
                                                   ELSE ls_item-PurchaseRequisitionItem )
                                            v3 = SWITCH #( lv_msgno
                                                   WHEN '008' THEN ls_item-Plant
                                                   ELSE ls_item-FollowOnDocument ) ) )
               TO reported-purreqsource.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zr_resapurreqsource IN LOCAL MODE
        ENTITY PurReqSource
          CREATE BY \_PettyCash
            FIELDS ( Reservation Plant Material ItemText Quantity BaseUnit
                     Amount Currency LocalSupplierName PettyCashStatus )
            WITH VALUE #( ( %tky    = ls_key-%tky
                            %target = VALUE #( ( %cid              = |PC{ ls_item-PurchaseRequisition }{ ls_item-PurchaseRequisitionItem }|
                                                 Reservation       = ls_item-Reservation
                                                 Plant             = ls_item-Plant
                                                 Material          = ls_item-Material
                                                 ItemText          = ls_item-PurchaseRequisitionItemText
                                                 Quantity          = ls_item-RequestedQuantity
                                                 BaseUnit          = ls_item-BaseUnit
                                                 Amount            = ls_key-%param-Amount
                                                 Currency          = ls_key-%param-Currency
                                                 LocalSupplierName = ls_key-%param-LocalSupplierName
                                                 PettyCashStatus   = 'CR' ) ) ) )
          UPDATE FIELDS ( SelectedSourceType SelectedSourceId SelectedDocType ProcessStatus StatusMessage )
            WITH VALUE #( ( %tky               = ls_key-%tky
                            SelectedSourceType = 'CASH'
                            SelectedSourceId   = 'PETITECAIS'
                            SelectedDocType    = ''
                            ProcessStatus      = 'CONV'
                            StatusMessage      = '' ) )
        FAILED DATA(ls_failed).

      IF ls_failed IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-purreqsource.
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY PurReqSource ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = ls_res ) ).
  ENDMETHOD.

ENDCLASS.
```

#### E5.4 Classe de sauvegarde

Ordre d'exécution RAP : `finalize` → `check_before_save` → **point de non-retour** → `adjust_numbers` →
`save_modified` → `cleanup`. Après le point de non-retour, **aucune erreur ne peut annuler la requête** : un échec
de BAPI est donc tracé (statut `ERR`, message) au lieu d'être bloquant.

```abap
CLASS lsc_zr_resapurreqsource DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS adjust_numbers   REDEFINITION.
    METHODS save_modified    REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_zr_resapurreqsource IMPLEMENTATION.

  METHOD adjust_numbers.
    " numérotation définitive des commandes petite caisse (late numbering)
    LOOP AT mapped-pettycash REFERENCE INTO DATA(lr_pc).
      CALL FUNCTION 'NUMBER_GET_NEXT'
        EXPORTING
          nr_range_nr = '01'
          object      = 'ZRESA_PC'
        IMPORTING
          number      = lr_pc->PettyCashOrder
        EXCEPTIONS
          OTHERS      = 1.
      IF sy-subrc <> 0.
        " après le point de non-retour : interruption volontaire, la tranche doit exister (J1)
        RAISE SHORTDUMP NEW cx_abap_invalid_value( value = 'ZRESA_PC' ).
      ENDIF.
      lr_pc->PurchaseRequisition     = lr_pc->%tmp-PurchaseRequisition.
      lr_pc->PurchaseRequisitionItem = lr_pc->%tmp-PurchaseRequisitionItem.
    ENDLOOP.
  ENDMETHOD.

  METHOD save_modified.
    DATA lt_pc TYPE STANDARD TABLE OF ztresa_pcorder.

    GET TIME STAMP FIELD DATA(lv_now).

    " 1. commandes petite caisse
    IF create-pettycash IS NOT INITIAL.
      lt_pc = CORRESPONDING #( create-pettycash MAPPING FROM ENTITY ).
      LOOP AT lt_pc ASSIGNING FIELD-SYMBOL(<ls_pc>).
        <ls_pc>-erdat      = sy-datum.
        <ls_pc>-ernam      = sy-uname.
        <ls_pc>-created_at = lv_now.
      ENDLOOP.
      INSERT ztresa_pcorder FROM TABLE @lt_pc.
    ENDIF.

    " 2. choix de source et conversions demandées
    IF update-purreqsource IS NOT INITIAL.
      READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
        ENTITY PurReqSource ALL FIELDS WITH CORRESPONDING #( update-purreqsource )
        RESULT DATA(lt_item).

      LOOP AT lt_item INTO DATA(ls_item).
        DATA(ls_row) = CORRESPONDING ztresa_srcsel( ls_item MAPPING FROM ENTITY ).

        SELECT SINGLE created_by, created_at FROM ztresa_srcsel
          WHERE banfn = @ls_row-banfn AND bnfpo = @ls_row-bnfpo
          INTO (@ls_row-created_by, @ls_row-created_at).
        IF sy-subrc <> 0.
          ls_row-created_by = sy-uname.
          ls_row-created_at = lv_now.
        ENDIF.
        ls_row-last_changed_by = sy-uname.
        ls_row-last_changed_at = lv_now.

        IF ls_item-ProcessStatus = 'REQ'.
          zcl_resa_src_po=>create_po_from_pr( EXPORTING is_item   = CORRESPONDING #( ls_item )
                                              IMPORTING ev_ebeln  = ls_row-ebeln
                                                        ev_msgtxt = ls_row-msgtxt ).
          IF ls_row-ebeln IS NOT INITIAL.
            ls_row-status = 'CONV'.
            APPEND VALUE #( %key = ls_item-%key
                            %msg = new_message( id = 'ZRESA_SRC' number = '013'
                                                severity = if_abap_behv_message=>severity-success
                                                v1 = ls_row-ebeln
                                                v2 = ls_item-PurchaseRequisition
                                                v3 = ls_item-PurchaseRequisitionItem ) )
                   TO reported-purreqsource.
          ELSE.
            ls_row-status = 'ERR'.
            APPEND VALUE #( %key = ls_item-%key
                            %msg = new_message( id = 'ZRESA_SRC' number = '014'
                                                severity = if_abap_behv_message=>severity-error
                                                v1 = ls_item-PurchaseRequisition
                                                v2 = ls_item-PurchaseRequisitionItem
                                                v3 = ls_row-msgtxt ) )
                   TO reported-purreqsource.
          ENDIF.
        ENDIF.

        MODIFY ztresa_srcsel FROM @ls_row.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
```

> **⚠️ À vérifier (R6)** — en numérotation tardive managée, la structure `mapped-pettycash` porte les clés
> provisoires dans `%tmp` et les clés définitives à renseigner. Contrôler dans l'éditeur (F2 sur `mapped`) les
> composants proposés par le niveau de release ; adapter les deux affectations si nécessaire.

> **ℹ️ Pourquoi relire le BO en `save_modified`**
> `update-purreqsource` ne contient que les champs modifiés (`%control`). La relecture en `IN LOCAL MODE`
> restitue l'image complète du tampon, indispensable pour un `MODIFY` qui crée la ligne si elle n'existe pas.

#### E5.5 Classe de création des documents : `ZCL_RESA_SRC_PO`

```abap
CLASS zcl_resa_src_po DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ts_need,
        PurchaseRequisition     TYPE banfn,
        PurchaseRequisitionItem TYPE bnfpo,
        Plant                   TYPE werks_d,
        Material                TYPE matnr,
        RequestedQuantity       TYPE menge_d,
        BaseUnit                TYPE meins,
        DeliveryDate            TYPE eindt,
        PurchasingGroup         TYPE bkgrp,
        SelectedSourceType      TYPE zresa_srctype,
        SelectedSourceId        TYPE zresa_srcid,
        SelectedDocType         TYPE esart,
      END OF ts_need.

    "! Commande d'achat (EDI) ou de transfert (WHSE / STOR), avec ou sans référence à une DA
    CLASS-METHODS create_po_from_pr
      IMPORTING is_item   TYPE ts_need
      EXPORTING ev_ebeln  TYPE ebeln
                ev_msgtxt TYPE bapi_msg.

    "! Demande d'achat de réapprovisionnement manuel (Alternative 1)
    CLASS-METHODS create_pr
      IMPORTING is_item   TYPE ts_need
      EXPORTING ev_banfn  TYPE banfn
                ev_msgtxt TYPE bapi_msg.
  PRIVATE SECTION.
    CLASS-METHODS first_error
      IMPORTING it_return        TYPE bapiret2_t
      RETURNING VALUE(rv_msgtxt) TYPE bapi_msg.
ENDCLASS.

CLASS zcl_resa_src_po IMPLEMENTATION.

  METHOD create_po_from_pr.
    DATA: ls_header  TYPE bapimepoheader,
          ls_headerx TYPE bapimepoheaderx,
          lt_item    TYPE STANDARD TABLE OF bapimepoitem,
          lt_itemx   TYPE STANDARD TABLE OF bapimepoitemx,
          lt_sched   TYPE STANDARD TABLE OF bapimeposchedule,
          lt_schedx  TYPE STANDARD TABLE OF bapimeposchedulx,
          lt_return  TYPE bapiret2_t,
          lv_date    TYPE char10.

    CLEAR: ev_ebeln, ev_msgtxt.

    DATA(ls_doc) = zcl_resa_src_custo=>get_doc_type( iv_plant   = is_item-Plant
                                                     iv_srctype = is_item-SelectedSourceType ).

    " société de la division réceptrice
    SELECT SINGLE k~bukrs
      FROM t001w AS w INNER JOIN t001k AS k ON k~bwkey = w~bwkey
      WHERE w~werks = @is_item-Plant
      INTO @DATA(lv_bukrs).

    ls_header = VALUE #( comp_code = lv_bukrs
                         doc_type  = is_item-SelectedDocType
                         purch_org = ls_doc-ekorg
                         pur_group = COND #( WHEN ls_doc-ekgrp IS NOT INITIAL
                                             THEN ls_doc-ekgrp ELSE is_item-PurchasingGroup ) ).
    ls_headerx = VALUE #( comp_code = abap_true doc_type = abap_true
                          purch_org = abap_true pur_group = abap_true ).

    CASE is_item-SelectedSourceType.
      WHEN 'EDI'.
        ls_header-vendor  = |{ CONV lifnr( is_item-SelectedSourceId ) ALPHA = IN }|.
        ls_headerx-vendor = abap_true.
      WHEN 'WHSE' OR 'STOR'.
        ls_header-suppl_plnt  = is_item-SelectedSourceId.
        ls_headerx-suppl_plnt = abap_true.
    ENDCASE.

    lt_item  = VALUE #( ( po_item       = '00010'
                          material_long = is_item-Material
                          plant         = is_item-Plant
                          quantity      = is_item-RequestedQuantity
                          po_unit       = is_item-BaseUnit
                          preq_no       = is_item-PurchaseRequisition
                          preq_item     = is_item-PurchaseRequisitionItem ) ).
    lt_itemx = VALUE #( ( po_item       = '00010'   po_itemx  = abap_true
                          material_long = abap_true plant     = abap_true
                          quantity      = abap_true po_unit   = abap_true
                          preq_no       = COND #( WHEN is_item-PurchaseRequisition IS NOT INITIAL THEN abap_true )
                          preq_item     = COND #( WHEN is_item-PurchaseRequisition IS NOT INITIAL THEN abap_true ) ) ).

    " ⚠️ R7 : la date de livraison de l'échéancier est au format externe
    CALL FUNCTION 'CONVERT_DATE_TO_EXTERNAL'
      EXPORTING date_internal = is_item-DeliveryDate
      IMPORTING date_external = lv_date
      EXCEPTIONS OTHERS       = 1.
    lt_sched  = VALUE #( ( po_item = '00010' sched_line = '0001'
                           delivery_date = lv_date quantity = is_item-RequestedQuantity ) ).
    lt_schedx = VALUE #( ( po_item = '00010' sched_line = '0001'
                           po_itemx = abap_true sched_linex = abap_true
                           delivery_date = abap_true quantity = abap_true ) ).

    CALL FUNCTION 'BAPI_PO_CREATE1'
      EXPORTING
        poheader         = ls_header
        poheaderx        = ls_headerx
      IMPORTING
        exppurchaseorder = ev_ebeln
      TABLES
        return           = lt_return
        poitem           = lt_item
        poitemx          = lt_itemx
        poschedule       = lt_sched
        poschedulex      = lt_schedx.
    " pas de BAPI_TRANSACTION_COMMIT : l'unité de travail est close par RAP

    IF ev_ebeln IS INITIAL.
      ev_msgtxt = first_error( lt_return ).
    ENDIF.
  ENDMETHOD.

  METHOD create_pr.
    DATA: lt_item   TYPE STANDARD TABLE OF bapimereqitemimp,
          lt_itemx  TYPE STANDARD TABLE OF bapimereqitemx,
          lt_return TYPE bapiret2_t.

    CLEAR: ev_banfn, ev_msgtxt.
    DATA(ls_cfg) = zcl_resa_src_custo=>get_repl_cfg( is_item-Plant ).

    lt_item  = VALUE #( ( preq_item     = '00010'
                          pur_group     = ls_cfg-ekgrp
                          material_long = is_item-Material
                          plant         = is_item-Plant
                          quantity      = is_item-RequestedQuantity
                          unit          = is_item-BaseUnit
                          deliv_date    = is_item-DeliveryDate ) ).
    lt_itemx = VALUE #( ( preq_item = '00010' preq_itemx = abap_true
                          pur_group = abap_true material_long = abap_true plant = abap_true
                          quantity  = abap_true unit = abap_true deliv_date = abap_true ) ).

    CALL FUNCTION 'BAPI_PR_CREATE'
      EXPORTING
        prheader  = VALUE bapimereqheader( pr_type = ls_cfg-bsart_pr )
        prheaderx = VALUE bapimereqheaderx( pr_type = abap_true )
      IMPORTING
        number    = ev_banfn
      TABLES
        return    = lt_return
        pritem    = lt_item
        pritemx   = lt_itemx.

    IF ev_banfn IS INITIAL.
      ev_msgtxt = first_error( lt_return ).
    ENDIF.
  ENDMETHOD.

  METHOD first_error.
    rv_msgtxt = VALUE #( it_return[ type = 'E' ]-message
                         DEFAULT VALUE #( it_return[ type = 'A' ]-message OPTIONAL ) ).
  ENDMETHOD.

ENDCLASS.
```

> **⚠️ R7 — tests SE37 obligatoires avant intégration**
> Exécuter `BAPI_PO_CREATE1` et `BAPI_PR_CREATE` en SE37 avec les valeurs d'un poste réel, **sans** commit, pour
> valider : format de la date (`DELIVERY_DATE` externe, `DELIV_DATE` interne), unité (`PO_UNIT` / `UNIT` interne
> ou ISO), champs obligatoires imposés par les types de document et par le paramétrage STO, et reprise des
> données de la DA quand `PREQ_NO` est renseigné. Ajuster le code ci-dessus d'après le résultat.

> **⚠️ Une commande par unité de travail**
> `BAPI_PO_CREATE1` n'est pas conçu pour être appelé plusieurs fois sans commit intermédiaire. Les actions
> sont annotées `invocationGrouping: #ISOLATED` (F3) : sur une sélection multiple, Fiori elements envoie un
> changeset par poste, donc une sauvegarde RAP par commande.

---

### E6 — BO de création : `ZBP_R_RESAREPLENREQUEST`

```abap
CLASS lhc_ReplenRequest DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK ReplenRequest.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ReplenRequest RESULT result.

    METHODS CreatePurchaseRequisition FOR MODIFY
      IMPORTING keys FOR ACTION ReplenRequest~CreatePurchaseRequisition RESULT result.

    METHODS CreateReplenishmentOrder FOR MODIFY
      IMPORTING keys FOR ACTION ReplenRequest~CreateReplenishmentOrder RESULT result.
ENDCLASS.

CLASS lhc_ReplenRequest IMPLEMENTATION.

  METHOD lock.
    " instances jamais modifiées après création : rien à verrouiller
  ENDMETHOD.

  METHOD get_global_authorizations.
    " contrôle sans division ; la division est contrôlée dans chaque action
    IF requested_authorizations-%action-CreatePurchaseRequisition = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'M_BANF_WRK' ID 'ACTVT' FIELD '01' ID 'WERKS' DUMMY.
      result-%action-CreatePurchaseRequisition = COND #( WHEN sy-subrc = 0
        THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%action-CreateReplenishmentOrder = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'M_BEST_WRK' ID 'ACTVT' FIELD '01' ID 'WERKS' DUMMY.
      result-%action-CreateReplenishmentOrder = COND #( WHEN sy-subrc = 0
        THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD CreateReplenishmentOrder.
    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_p)     = ls_key-%param.
      DATA(lv_msgno) = CONV symsgno( '' ).
      DATA(ls_doc)   = zcl_resa_src_custo=>get_doc_type( iv_plant = ls_p-Plant iv_srctype = ls_p-SourceType ).

      AUTHORITY-CHECK OBJECT 'M_BEST_WRK' ID 'ACTVT' FIELD '01' ID 'WERKS' FIELD ls_p-Plant.
      IF sy-subrc <> 0.
        lv_msgno = '006'.
      ELSEIF ls_p-Quantity <= 0.
        lv_msgno = '019'.
      ELSEIF ls_p-SourceType = 'CASH'.
        lv_msgno = '004'.
      ELSEIF ls_doc-bsart IS INITIAL.
        lv_msgno = '002'.
      ELSE.
        SELECT SINGLE @abap_true FROM zi_resasrccandidate
          WHERE Plant = @ls_p-Plant AND Material = @ls_p-Material
            AND SourceType = @ls_p-SourceType AND SourceId = @ls_p-SourceId
          INTO @DATA(lv_found).
        IF sy-subrc <> 0.
          lv_msgno = '012'.
        ELSE.
          AUTHORITY-CHECK OBJECT 'M_BEST_BSA' ID 'ACTVT' FIELD '01' ID 'BSART' FIELD ls_doc-bsart.
          IF sy-subrc <> 0.
            lv_msgno = '005'.
          ENDIF.
        ENDIF.
      ENDIF.

      IF lv_msgno IS NOT INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-replenrequest.
        APPEND VALUE #( %cid = ls_key-%cid
                        %msg = new_message( id = 'ZRESA_SRC' number = lv_msgno
                                            severity = if_abap_behv_message=>severity-error
                                            v1 = SWITCH #( lv_msgno WHEN '005' THEN ls_doc-bsart
                                                                    WHEN '006' THEN ls_p-Plant
                                                                    ELSE ls_p-SourceType )
                                            v2 = SWITCH #( lv_msgno WHEN '012' THEN ls_p-SourceId
                                                                    ELSE ls_p-Plant )
                                            v3 = ls_p-Material
                                            v4 = ls_p-Plant ) )
               TO reported-replenrequest.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zr_resareplenrequest IN LOCAL MODE
        ENTITY ReplenRequest
          CREATE FIELDS ( RequestType Plant Material ItemText Quantity BaseUnit DeliveryDate
                          SourceType SourceId DocType ProcessStatus )
          WITH VALUE #( ( %cid          = ls_key-%cid
                          RequestType   = 'PO'
                          Plant         = ls_p-Plant
                          Material      = ls_p-Material
                          ItemText      = ls_p-ItemText
                          Quantity      = ls_p-Quantity
                          BaseUnit      = ls_p-BaseUnit
                          DeliveryDate  = ls_p-DeliveryDate
                          SourceType    = ls_p-SourceType
                          SourceId      = ls_p-SourceId
                          DocType       = ls_doc-bsart
                          ProcessStatus = 'REQ' ) )
        MAPPED DATA(ls_mapped).

      READ ENTITIES OF zr_resareplenrequest IN LOCAL MODE
        ENTITY ReplenRequest ALL FIELDS
        WITH VALUE #( ( %key-RequestUuid = ls_mapped-replenrequest[ 1 ]-RequestUuid ) )
        RESULT DATA(lt_new).

      APPEND VALUE #( %cid = ls_key-%cid %param = lt_new[ 1 ] ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD CreatePurchaseRequisition.
    " Même structure que CreateReplenishmentOrder, avec :
    "  - contrôle M_BANF_WRK ACTVT 01 sur la division (message 006) ;
    "  - contrôle ZCL_RESA_SRC_CUSTO=>GET_REPL_CFG( ) non vide (message 016) ;
    "  - quantité > 0 (message 019) ;
    "  - pas de source : RequestType = 'PR', SourceType / SourceId / DocType à blanc.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zr_resareplenrequest DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified    REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_zr_resareplenrequest IMPLEMENTATION.

  METHOD save_modified.
    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT create-replenrequest INTO DATA(ls_req).
      DATA(ls_row) = CORRESPONDING ztresa_replreq( ls_req MAPPING FROM ENTITY ).
      DATA(ls_need) = VALUE zcl_resa_src_po=>ts_need(
                        Plant              = ls_req-Plant
                        Material           = ls_req-Material
                        RequestedQuantity  = ls_req-Quantity
                        BaseUnit           = ls_req-BaseUnit
                        DeliveryDate       = ls_req-DeliveryDate
                        SelectedSourceType = ls_req-SourceType
                        SelectedSourceId   = ls_req-SourceId
                        SelectedDocType    = ls_req-DocType ).

      CASE ls_req-RequestType.
        WHEN 'PR'.
          zcl_resa_src_po=>create_pr( EXPORTING is_item = ls_need
                                      IMPORTING ev_banfn = ls_row-banfn ev_msgtxt = ls_row-msgtxt ).
          ls_row-status = COND #( WHEN ls_row-banfn IS NOT INITIAL THEN 'CONV' ELSE 'ERR' ).
        WHEN 'PO'.
          zcl_resa_src_po=>create_po_from_pr( EXPORTING is_item = ls_need
                                              IMPORTING ev_ebeln = ls_row-ebeln ev_msgtxt = ls_row-msgtxt ).
          ls_row-status = COND #( WHEN ls_row-ebeln IS NOT INITIAL THEN 'CONV' ELSE 'ERR' ).
      ENDCASE.

      ls_row-created_by = sy-uname.
      ls_row-created_at = lv_now.
      INSERT ztresa_replreq FROM @ls_row.

      APPEND VALUE #( %key = ls_req-%key
                      %msg = new_message( id = 'ZRESA_SRC'
                                          number = COND #( WHEN ls_row-status = 'ERR' THEN '014'
                                                           WHEN ls_req-RequestType = 'PR' THEN '015'
                                                           ELSE '013' )
                                          severity = COND #( WHEN ls_row-status = 'ERR'
                                                             THEN if_abap_behv_message=>severity-error
                                                             ELSE if_abap_behv_message=>severity-success )
                                          v1 = COND #( WHEN ls_row-status = 'ERR' THEN ls_row-werks
                                                       WHEN ls_req-RequestType = 'PR' THEN ls_row-banfn
                                                       ELSE ls_row-ebeln )
                                          v2 = ls_row-matnr
                                          v3 = ls_row-msgtxt ) )
             TO reported-replenrequest.
    ENDLOOP.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
```

> **ℹ️ Une demande en erreur reste tracée**
> La ligne de `ZTRESA_REPLREQ` est insérée même si la BAPI échoue (statut `ERR`, message) : l'utilisateur la
> retrouve dans la liste de l'application de création et peut ressaisir.

> **📸 COPIE D'ÉCRAN N°11** — ADT : classes `ZBP_R_RESAPURREQSOURCE` et `ZCL_RESA_SRC_PO` activées
> *Remplacer cette ligne par :* `![Copie 11](images/RESA-SRC-RAP/capture-11.png)`

#### Critères de validation des parties D et E

- Les behavior definitions et classes sont activées sans avertissement bloquant.
- Test EML en console (classe de test ABAP Unit ou programme `$TMP`) : `SelectSource` puis `COMMIT ENTITIES`
  crée la ligne `ZTRESA_SRCSEL` ; `ConvertToPurchaseOrder` puis `COMMIT ENTITIES` crée la commande et renseigne
  la DA.

---

## Partie F — Projections et annotations

### F1 — Vues de projection

#### F1.1 Alternative 1 — `ZC_ResaPurReqSourceAll`

```abap
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@Search.searchable: true
@EndUserText.label: 'Détermination de la source - toutes les DA'
@ObjectModel.semanticKey: [ 'PurchaseRequisition', 'PurchaseRequisitionItem' ]

define root view entity ZC_ResaPurReqSourceAll
  provider contract transactional_query
  as projection on ZR_ResaPurReqSource
{
      @Search.defaultSearchElement: true
  key PurchaseRequisition,
  key PurchaseRequisitionItem,
      @Search.defaultSearchElement: true
      Reservation,
      OriginType,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ResaPlantVH', element: 'Plant' } }]
      Plant,
      PurchasingGroup,
      @Search.defaultSearchElement: true
      Material,
      PurchaseRequisitionItemText,
      DeliveryDate,
      RequestedQuantity,
      BaseUnit,
      ItemPrice,
      Currency,
      PurchaseOrder,
      PurchaseOrderItem,
      PettyCashOrder,
      FollowOnDocument,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ResaSourceTypeVH', element: 'SourceType' } }]
      SelectedSourceType,
      SelectedSourceId,
      SelectedDocType,
      SourceStatus,
      SourceCriticality,
      StatusMessage,
      SourceOptionCount,
      SupplierSourceCount,
      PettyCashEligible,
      CreatedBy,
      LastChangedBy,
      LastChangedAt,

      _SourceOption : redirected to composition child ZC_ResaSourceOptAll,
      _PettyCash    : redirected to composition child ZC_ResaPettyCashAll
}
```

```abap
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Options de source - Alternative 1'

define view entity ZC_ResaSourceOptAll
  as projection on ZR_ResaSourceOption
{
  key PurchaseRequisition,
  key PurchaseRequisitionItem,
  key SourceType,
  key SourceId,
      Plant,
      SourceName,
      SourceRank,
      Availability,
      AvailabilityCriticality,
      AvailableQuantity,
      BaseUnit,
      LeadTimeDays,
      NetPrice,
      Currency,
      IsSelected,
      _Item : redirected to parent ZC_ResaPurReqSourceAll
}
```

```abap
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Commandes petite caisse - Alternative 1'

define view entity ZC_ResaPettyCashAll
  as projection on ZR_ResaPettyCash
{
  key PurchaseRequisition,
  key PurchaseRequisitionItem,
  key PettyCashOrder,
      Reservation,
      Plant,
      Material,
      ItemText,
      Quantity,
      BaseUnit,
      Amount,
      Currency,
      LocalSupplierName,
      PettyCashStatus,
      CreationDate,
      CreatedByUser,
      _Item : redirected to parent ZC_ResaPurReqSourceAll
}
```

#### F1.2 Alternative 2 — `ZC_ResaPurReqSourceResa`

Copie des trois projections F1.1 avec les substitutions suivantes :

| Élément | Alternative 1 | Alternative 2 |
|---|---|---|
| Racine | `ZC_ResaPurReqSourceAll` | `ZC_ResaPurReqSourceResa` + clause `where OriginType = 'RESA'` après `as projection on ZR_ResaPurReqSource` |
| Option | `ZC_ResaSourceOptAll` | `ZC_ResaSourceOptResa` |
| Petite caisse | `ZC_ResaPettyCashAll` | `ZC_ResaPettyCashResa` |
| Libellés | `… - toutes les DA` / `… - Alternative 1` | `… - réservations` / `… - Alternative 2` |

> **ℹ️ Filtre dur ou variante**
> En Alternative 2, le filtre sur les réservations est **dans la projection** : un utilisateur ne peut pas
> l'enlever. Le filtre « à traiter » (`SourceStatus ≠ CONV`) reste une **variante** de l'écran, que l'utilisateur
> peut lever pour consulter l'historique.

#### F1.3 Création — `ZC_ResaReplenRequestPR` et `ZC_ResaReplenRequestPO`

```abap
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Demandes d''achat de réapprovisionnement saisies'

define root view entity ZC_ResaReplenRequestPR
  provider contract transactional_query
  as projection on ZR_ResaReplenRequest
  where RequestType = 'PR'
{
  key RequestUuid,
      RequestType,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ResaPlantVH', element: 'Plant' } }]
      Plant,
      Material,
      ItemText,
      Quantity,
      BaseUnit,
      DeliveryDate,
      SourceType,
      SourceId,
      DocType,
      ProcessStatus,
      StatusCriticality,
      PurchaseRequisition,
      PurchaseOrder,
      StatusMessage,
      CreatedBy,
      CreatedAt
}
```

`ZC_ResaReplenRequestPO` : identique avec `where RequestType = 'PO'` et le libellé
`Commandes de réapprovisionnement saisies`.

---

### F2 — Behavior definitions de projection

`ZC_ResaPurReqSourceAll` (idem `ZC_ResaPurReqSourceResa` avec les noms Alternative 2) :

```abap
projection;
strict;

define behavior for ZC_ResaPurReqSourceAll alias PurReqSource
{
  use action ConvertToPurchaseOrder;
  use action CreatePettyCashOrder;

  use association _SourceOption;
  use association _PettyCash;
}

define behavior for ZC_ResaSourceOptAll alias SourceOption
{
  use action SelectSource;
  use association _Item;
}

define behavior for ZC_ResaPettyCashAll alias PettyCash
{
  use association _Item;
}
```

`ZC_ResaReplenRequestPR` :

```abap
projection;
strict;

define behavior for ZC_ResaReplenRequestPR alias ReplenRequest
{
  use action CreatePurchaseRequisition;
}
```

`ZC_ResaReplenRequestPO` : identique avec `use action CreateReplenishmentOrder;`.

> **ℹ️ Ce qui n'est pas exposé**
> `update`, `create` et la création par association `_PettyCash` ne figurent dans **aucune** projection : l'écran
> ne peut ni modifier un poste ni créer une commande petite caisse autrement que par les actions contrôlées.
> C'est aussi ce qui résout l'écart de la maquette : l'Alternative 1 de détermination n'expose aucune création.

---

### F3 — Extensions de métadonnées

#### F3.1 `ZC_ResaPurReqSourceAll` (liste et page objet)

```abap
@Metadata.layer: #CORE

@UI.headerInfo: { typeName:       'Poste à approvisionner',
                  typeNamePlural: 'Postes à approvisionner',
                  title:       { type: #STANDARD, value: 'PurchaseRequisition' },
                  description: { type: #STANDARD, value: 'PurchaseRequisitionItemText' } }

@UI.presentationVariant: [ { sortOrder: [ { by: 'DeliveryDate', direction: #ASC } ],
                             visualizations: [ { type: #AS_LINEITEM } ] } ]

@UI.selectionVariant: [ { qualifier: 'ATraiter',
                          text: 'Postes à traiter',
                          filter: 'SourceStatus NE ''CONV''' } ]

annotate entity ZC_ResaPurReqSourceAll with
@UI.facet: [
  { id: 'Statut',   purpose: #HEADER,   type: #DATAPOINT_REFERENCE,
    targetQualifier: 'Statut', position: 10 },
  { id: 'Besoin',   purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
    targetQualifier: 'GrpBesoin', label: 'Besoin', position: 10 },
  { id: 'Sources',  purpose: #STANDARD, type: #LINEITEM_REFERENCE,
    targetElement: '_SourceOption', label: 'Sources d''approvisionnement disponibles', position: 20 },
  { id: 'Resultat', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
    targetQualifier: 'GrpResultat', label: 'Approvisionnement retenu', position: 30 },
  { id: 'PetiteCaisse', purpose: #STANDARD, type: #LINEITEM_REFERENCE,
    targetElement: '_PettyCash', label: 'Commande petite caisse', position: 40 }
]
{
  @UI: { lineItem:       [ { position: 10, importance: #HIGH, label: 'Demande d''achat' },
                           { type: #FOR_ACTION, dataAction: 'ConvertToPurchaseOrder',
                             label: 'Convertir en commande', invocationGrouping: #ISOLATED },
                           { type: #FOR_ACTION, dataAction: 'CreatePettyCashOrder',
                             label: 'Commande petite caisse', invocationGrouping: #ISOLATED } ],
         identification: [ { type: #FOR_ACTION, dataAction: 'ConvertToPurchaseOrder',
                             label: 'Convertir en commande', position: 10 },
                           { type: #FOR_ACTION, dataAction: 'CreatePettyCashOrder',
                             label: 'Commande petite caisse', position: 20 } ],
         selectionField: [ { position: 10 } ],
         fieldGroup:     [ { qualifier: 'GrpBesoin', position: 10 } ] }
  PurchaseRequisition;

  @UI.fieldGroup: [ { qualifier: 'GrpBesoin', position: 20 } ]
  PurchaseRequisitionItem;

  @UI: { lineItem:       [ { position: 20, label: 'Réservation' } ],
         selectionField: [ { position: 20 } ],
         fieldGroup:     [ { qualifier: 'GrpBesoin', position: 30 } ] }
  Reservation;

  @UI: { lineItem:       [ { position: 30, label: 'Origine' } ],
         selectionField: [ { position: 30 } ],
         fieldGroup:     [ { qualifier: 'GrpBesoin', position: 40 } ] }
  OriginType;

  @UI: { lineItem:       [ { position: 40, importance: #HIGH, label: 'Division' } ],
         selectionField: [ { position: 40 } ],
         fieldGroup:     [ { qualifier: 'GrpBesoin', position: 50 } ] }
  Plant;

  @UI: { lineItem:       [ { position: 50, importance: #HIGH, label: 'Article' } ],
         fieldGroup:     [ { qualifier: 'GrpBesoin', position: 60 } ] }
  Material;

  @UI: { lineItem:       [ { position: 60, label: 'Désignation' } ],
         fieldGroup:     [ { qualifier: 'GrpBesoin', position: 70 } ] }
  PurchaseRequisitionItemText;

  @UI: { lineItem:       [ { position: 70, label: 'Quantité' } ],
         fieldGroup:     [ { qualifier: 'GrpBesoin', position: 80 } ] }
  RequestedQuantity;

  @UI: { lineItem:       [ { position: 80, label: 'Date de besoin' } ],
         fieldGroup:     [ { qualifier: 'GrpBesoin', position: 90 } ] }
  DeliveryDate;

  @UI: { lineItem:       [ { position: 90, importance: #HIGH, label: 'Sources' } ],
         fieldGroup:     [ { qualifier: 'GrpResultat', position: 10 } ] }
  SourceOptionCount;

  @UI: { lineItem:       [ { position: 100, label: 'Dont fournisseurs' } ],
         fieldGroup:     [ { qualifier: 'GrpResultat', position: 20 } ] }
  SupplierSourceCount;

  @UI: { lineItem:       [ { position: 110, label: 'Source retenue' } ],
         selectionField: [ { position: 50 } ],
         fieldGroup:     [ { qualifier: 'GrpResultat', position: 30 } ] }
  SelectedSourceType;

  @UI.fieldGroup: [ { qualifier: 'GrpResultat', position: 40, label: 'Identifiant de la source' } ]
  SelectedSourceId;

  @UI.fieldGroup: [ { qualifier: 'GrpResultat', position: 50, label: 'Type de document' } ]
  SelectedDocType;

  @UI: { lineItem:       [ { position: 120, importance: #HIGH, label: 'Statut',
                             criticality: 'SourceCriticality' } ],
         selectionField: [ { position: 60 } ],
         dataPoint:      { qualifier: 'Statut', title: 'Statut', criticality: 'SourceCriticality' },
         fieldGroup:     [ { qualifier: 'GrpResultat', position: 60, criticality: 'SourceCriticality' } ] }
  SourceStatus;

  @UI.fieldGroup: [ { qualifier: 'GrpResultat', position: 70, label: 'Message' } ]
  StatusMessage;

  @UI: { lineItem:       [ { position: 130, label: 'Document aval' } ],
         fieldGroup:     [ { qualifier: 'GrpResultat', position: 80 } ] }
  FollowOnDocument;

  @UI.hidden: true
  SourceCriticality;
  @UI.hidden: true
  PettyCashEligible;
  @UI.hidden: true
  ProcessStatus;
}
```

> **ℹ️ Libellés des codes**
> `OriginType`, `SourceStatus`, `SelectedSourceType` s'affichent en code. Pour afficher les libellés, ajouter
> dans les vues du BO les éléments texte (`@ObjectModel.text.element`) lus depuis les textes des valeurs fixes
> de domaine (C6), sur le modèle des champs `…Text` du cube de la chaîne.

#### F3.2 `ZC_ResaSourceOptAll` (tableau comparatif)

```abap
@Metadata.layer: #CORE

@UI.headerInfo: { typeName: 'Source d''approvisionnement', typeNamePlural: 'Sources d''approvisionnement',
                  title: { type: #STANDARD, value: 'SourceName' } }

-- Aucun tri par disponibilité ni par prix : choix manuel (décision de conception inchangée)
@UI.presentationVariant: [ { sortOrder: [ { by: 'SourceType', direction: #ASC },
                                          { by: 'SourceRank', direction: #ASC } ],
                             visualizations: [ { type: #AS_LINEITEM } ] } ]

annotate entity ZC_ResaSourceOptAll with
{
  @UI.lineItem: [ { position: 10, importance: #HIGH, label: 'Type de source' },
                  { type: #FOR_ACTION, dataAction: 'SelectSource', label: 'Retenir cette source',
                    invocationGrouping: #ISOLATED } ]
  SourceType;

  @UI.lineItem: [ { position: 20, importance: #HIGH, label: 'Source' } ]
  SourceName;

  @UI.lineItem: [ { position: 30, importance: #HIGH, label: 'Disponibilité',
                    criticality: 'AvailabilityCriticality' } ]
  Availability;

  @UI.lineItem: [ { position: 40, label: 'Quantité disponible' } ]
  AvailableQuantity;

  @UI.lineItem: [ { position: 50, label: 'Délai (jours)' } ]
  LeadTimeDays;

  @UI.lineItem: [ { position: 60, label: 'Prix' } ]
  NetPrice;

  @UI.lineItem: [ { position: 70, label: 'Rang' } ]
  SourceRank;

  @UI.lineItem: [ { position: 80, label: 'Retenue' } ]
  IsSelected;

  @UI.lineItem: [ { position: 90, label: 'Identifiant' } ]
  SourceId;

  @UI.hidden: true
  AvailabilityCriticality;
}
```

#### F3.3 `ZC_ResaPettyCashAll`

`lineItem` : `PettyCashOrder` (10), `LocalSupplierName` (20), `Amount` (30), `PettyCashStatus` (40),
`CreationDate` (50), `CreatedByUser` (60) — mêmes libellés que la maquette `ZC_ResaPettyCashOrder.asddlxs`.

#### F3.4 `ZC_ResaReplenRequestPO` (et `…PR`)

```abap
@Metadata.layer: #CORE

@UI.headerInfo: { typeName: 'Commande de réapprovisionnement', typeNamePlural: 'Commandes de réapprovisionnement',
                  title: { type: #STANDARD, value: 'Material' },
                  description: { type: #STANDARD, value: 'ItemText' } }

@UI.presentationVariant: [ { sortOrder: [ { by: 'CreatedAt', direction: #DESC } ],
                             visualizations: [ { type: #AS_LINEITEM } ] } ]

annotate entity ZC_ResaReplenRequestPO with
{
  -- action statique : aucun contexte, Fiori elements génère le dialogue de saisie des paramètres
  @UI.lineItem: [ { type: #FOR_ACTION, dataAction: 'CreateReplenishmentOrder',
                    label: 'Nouvelle commande de réapprovisionnement' },
                  { position: 10, importance: #HIGH, label: 'Division' } ]
  @UI.selectionField: [ { position: 10 } ]
  Plant;

  @UI.lineItem: [ { position: 20, importance: #HIGH, label: 'Article' } ]
  Material;
  @UI.lineItem: [ { position: 30, label: 'Désignation' } ]
  ItemText;
  @UI.lineItem: [ { position: 40, label: 'Quantité' } ]
  Quantity;
  @UI.lineItem: [ { position: 50, label: 'Date de besoin' } ]
  DeliveryDate;
  @UI.lineItem: [ { position: 60, label: 'Type de source' } ]
  SourceType;
  @UI.lineItem: [ { position: 70, label: 'Source' } ]
  SourceId;
  @UI.lineItem: [ { position: 80, importance: #HIGH, label: 'Commande' } ]
  PurchaseOrder;
  @UI.lineItem: [ { position: 90, importance: #HIGH, label: 'Statut', criticality: 'StatusCriticality' } ]
  @UI.selectionField: [ { position: 20 } ]
  ProcessStatus;
  @UI.lineItem: [ { position: 100, label: 'Message' } ]
  StatusMessage;
  @UI.lineItem: [ { position: 110, label: 'Saisie le' } ]
  CreatedAt;

  @UI.hidden: true
  StatusCriticality;
}
```

Pour `ZC_ResaReplenRequestPR` : action `CreatePurchaseRequisition` (« Nouvelle demande d'achat »), colonne
`PurchaseRequisition` à la place de `PurchaseOrder`, colonnes de source supprimées.

> **📸 COPIE D'ÉCRAN N°12** — ADT : extension de métadonnées `ZC_ResaPurReqSourceAll`
> *Remplacer cette ligne par :* `![Copie 12](images/RESA-SRC-RAP/capture-12.png)`

---

### F4 — Contrôle d'accès des projections

Une DCL par projection, par héritage (modèle pour toutes) :

```abap
@EndUserText.label: 'Accès - détermination de source Alternative 1'
@MappingRole: true
define role ZC_ResaPurReqSourceAll {
  grant select on ZC_ResaPurReqSourceAll
    where inheriting conditions from entity ZR_ResaPurReqSource;
}
```

| Projection | Hérite de |
|---|---|
| `ZC_ResaPurReqSourceAll`, `ZC_ResaPurReqSourceResa` | `ZR_ResaPurReqSource` |
| `ZC_ResaSourceOptAll`, `ZC_ResaSourceOptResa` | `ZR_ResaSourceOption` |
| `ZC_ResaPettyCashAll`, `ZC_ResaPettyCashResa` | `ZR_ResaPettyCash` |
| `ZC_ResaReplenRequestPR`, `ZC_ResaReplenRequestPO` | `ZR_ResaReplenRequest` |

---

## Partie G — Services OData V4

### G1 — Service definitions

ADT → clic droit sur la projection racine → *New Service Definition*.

```abap
@EndUserText.label: 'Détermination de la source - Alternative 1'
define service ZUI_RESASRC_ALT1 {
  expose ZC_ResaPurReqSourceAll as PurReqSource;
  expose ZC_ResaSourceOptAll    as SourceOption;
  expose ZC_ResaPettyCashAll    as PettyCash;
  expose ZI_ResaPlantVH         as PlantVH;
  expose ZI_ResaSourceTypeVH    as SourceTypeVH;
}
```

```abap
@EndUserText.label: 'Création d''une demande d''achat - Alternative 1'
define service ZUI_RESAREPL_ALT1 {
  expose ZC_ResaReplenRequestPR as ReplenRequest;
  expose ZI_ResaPlantVH         as PlantVH;
}
```

```abap
@EndUserText.label: 'Réservations à approvisionner - Alternative 2'
define service ZUI_RESASRC_ALT2 {
  expose ZC_ResaPurReqSourceResa as PurReqSource;
  expose ZC_ResaSourceOptResa    as SourceOption;
  expose ZC_ResaPettyCashResa    as PettyCash;
  expose ZI_ResaPlantVH          as PlantVH;
  expose ZI_ResaSourceTypeVH     as SourceTypeVH;
}
```

```abap
@EndUserText.label: 'Commande de réapprovisionnement - Alternative 2'
define service ZUI_RESAREPL_ALT2 {
  expose ZC_ResaReplenRequestPO as ReplenRequest;
  expose ZI_ResaPlantVH         as PlantVH;
  expose ZI_ResaSourceTypeVH    as SourceTypeVH;
  expose ZI_ResaSrcCandidateVH  as SourceCandidateVH;
}
```

> **ℹ️ Mêmes noms d'entités exposées**
> Les deux services de détermination exposent `PurReqSource` / `SourceOption` / `PettyCash` : les deux
> applications partagent ainsi la même structure de manifeste et le même fragment d'extension (H4).

### G2 — Service bindings

Pour chaque service definition : clic droit → *New Service Binding*.

| Service definition | Service binding | Type de binding |
|---|---|---|
| `ZUI_RESASRC_ALT1` | `ZUI_RESASRC_ALT1_O4` | OData V4 - UI |
| `ZUI_RESAREPL_ALT1` | `ZUI_RESAREPL_ALT1_O4` | OData V4 - UI |
| `ZUI_RESASRC_ALT2` | `ZUI_RESASRC_ALT2_O4` | OData V4 - UI |
| `ZUI_RESAREPL_ALT2` | `ZUI_RESAREPL_ALT2_O4` | OData V4 - UI |

1. Activer le binding.
2. Bouton **Publish** (publication locale) : le groupe de services est créé et enregistré.
3. Relever l'**URL du service** affichée dans l'éditeur (reprise dans les manifestes, H2).

> **📸 COPIE D'ÉCRAN N°13** — ADT : service binding `ZUI_RESASRC_ALT1_O4` publié, entités et associations listées
> *Remplacer cette ligne par :* `![Copie 13](images/RESA-SRC-RAP/capture-13.png)`

### G3 — Contrôle de publication et test

1. Transaction `/IWFND/V4_ADMIN` : vérifier la présence des quatre groupes de services, alias système `LOCAL`.
2. Dans l'éditeur du binding, sélectionner `PurReqSource` → **Preview** : l'aperçu Fiori elements s'ouvre.
3. Tester : liste, page objet, `Retenir cette source`, `Convertir en commande`.
4. Rejouer `$metadata` dans le navigateur par la route d'accès des utilisateurs.

> **📸 COPIE D'ÉCRAN N°14** — `/IWFND/V4_ADMIN` : les quatre groupes de services publiés
> *Remplacer cette ligne par :* `![Copie 14](images/RESA-SRC-RAP/capture-14.png)`

> **📸 COPIE D'ÉCRAN N°15** — Preview : page objet d'un poste, comparatif des sources
> *Remplacer cette ligne par :* `![Copie 15](images/RESA-SRC-RAP/capture-15.png)`

---

## Partie H — Applications Fiori elements V4

Les quatre applications maquettes (OData V2, dossiers `apps/alt1creation`, `apps/alt1source`,
`apps/alt2creation`, `apps/alt2source`) sont **régénérées** en V4. Les identifiants et intentions sont
**conservés**, ce qui garde les tuiles et les navigations du launchpad local.

| Application | Service | Entité principale | Intention |
|---|---|---|---|
| `zlr.alt1source` | `ZUI_RESASRC_ALT1_O4` | `PurReqSource` | `ResaSource-determineAll` |
| `zlr.alt1creation` | `ZUI_RESAREPL_ALT1_O4` | `ReplenRequest` | `ResaPurReq-create` |
| `zlr.alt2source` | `ZUI_RESASRC_ALT2_O4` | `PurReqSource` | `ResaSource-determineResa` |
| `zlr.alt2creation` | `ZUI_RESAREPL_ALT2_O4` | `ReplenRequest` | `ResaReplen-order` |

### H1 — Générer les projets

Pour chaque application :

1. VS Code → *SAP Fiori: Open Application Generator*.
2. Modèle **List Report Page**, version OData **V4**.
3. Source : *Connect to a system*, système S/4HANA, service ci-dessus.
4. Entité principale ci-dessus ; navigation vers `SourceOption` : **non** (le tableau est dans la page objet).
5. Module : nom de l'application sans préfixe (`alt1source`…), espace de noms `zlr`, titre repris de la maquette.
6. Configuration de déploiement : ABAP, package `ZRESA_SRC`, nom BSP `ZRESA_ALT1SRC` / `ZRESA_ALT1CRE` /
   `ZRESA_ALT2SRC` / `ZRESA_ALT2CRE` (15 caractères maximum).
7. Configuration Launchpad : objet sémantique et action de l'intention ci-dessus.
8. Version SAPUI5 minimale : **1.96**.

> **⚠️ Remplacement des maquettes**
> Générer dans un dossier temporaire puis remplacer le contenu du dossier maquette, en conservant
> `webapp/test/flpSandbox.html` s'il sert au launchpad local. Les dossiers `localService/ZCRESASRC_CDS`
> deviennent obsolètes : l'application V4 pointe sur le service réel ou sur un `metadata.xml` V4 récupéré du
> système pour le mode mock.

> **📸 COPIE D'ÉCRAN N°16** — Générateur : List Report V4 sur `ZUI_RESASRC_ALT1_O4`
> *Remplacer cette ligne par :* `![Copie 16](images/RESA-SRC-RAP/capture-16.png)`

---

### H2 — Manifeste des écrans de détermination

Extrait de `webapp/manifest.json` de `zlr.alt1source` (adapter l'URI et l'intention pour `zlr.alt2source`) :

```json
"sap.app": {
  "id": "zlr.alt1source",
  "dataSources": {
    "mainService": {
      "uri": "/sap/opu/odata4/sap/zui_resasrc_alt1_o4/srvd/sap/zui_resasrc_alt1/0001/",
      "type": "OData",
      "settings": { "odataVersion": "4.0", "annotations": [ "annotation" ] }
    },
    "annotation": {
      "type": "ODataAnnotation",
      "uri": "annotations/annotation.xml",
      "settings": { "localUri": "annotations/annotation.xml" }
    }
  }
},
"sap.ui5": {
  "routing": {
    "targets": {
      "PurReqSourceList": {
        "type": "Component",
        "name": "sap.fe.templates.ListReport",
        "options": {
          "settings": {
            "entitySet": "PurReqSource",
            "initialLoad": "Enabled",
            "defaultTemplateAnnotationPath": "com.sap.vocabularies.UI.v1.SelectionVariant#ATraiter",
            "variantManagement": "Page",
            "navigation": { "PurReqSource": { "detail": { "route": "PurReqSourceObjectPage" } } }
          }
        }
      },
      "PurReqSourceObjectPage": {
        "type": "Component",
        "name": "sap.fe.templates.ObjectPage",
        "options": { "settings": { "entitySet": "PurReqSource" } }
      }
    }
  }
}
```

> **⚠️ À vérifier** — l'URI exacte est celle relevée en G2 ; le paramètre `defaultTemplateAnnotationPath` et
> la forme des réglages (`entitySet` ou `contextPath`) sont ceux produits par le générateur pour la version
> 1.96 : conserver ce qu'il génère et n'ajouter que `initialLoad` et la variante par défaut.

---

### H3 — Side effects

Sans draft et sans *side effects* déclarables en behavior definition en 2021, l'écran doit être informé des
champs à relire après une action. Ajouter dans `webapp/annotations/annotation.xml` (l'alias `SAP__self` est
celui déclaré par le générateur pour l'espace de noms du service) :

```xml
<!-- après « Retenir cette source » : relire le poste et tout le comparatif -->
<Annotations Target="SAP__self.SelectSource(SAP__self.SourceOptionType)">
  <Annotation Term="Common.SideEffects">
    <Record Type="Common.SideEffectsType">
      <PropertyValue Property="TargetEntities">
        <Collection>
          <NavigationPropertyPath>_it/_Item</NavigationPropertyPath>
          <NavigationPropertyPath>_it/_Item/_SourceOption</NavigationPropertyPath>
        </Collection>
      </PropertyValue>
    </Record>
  </Annotation>
</Annotations>

<!-- après conversion : relire statut, document aval et message (renseignés en sauvegarde) -->
<Annotations Target="SAP__self.ConvertToPurchaseOrder(SAP__self.PurReqSourceType)">
  <Annotation Term="Common.SideEffects">
    <Record Type="Common.SideEffectsType">
      <PropertyValue Property="TargetProperties">
        <Collection>
          <String>_it/SourceStatus</String>
          <String>_it/SourceCriticality</String>
          <String>_it/FollowOnDocument</String>
          <String>_it/PurchaseOrder</String>
          <String>_it/StatusMessage</String>
        </Collection>
      </PropertyValue>
      <PropertyValue Property="TargetEntities">
        <Collection>
          <NavigationPropertyPath>_it/_SourceOption</NavigationPropertyPath>
        </Collection>
      </PropertyValue>
    </Record>
  </Annotation>
</Annotations>

<!-- après petite caisse : relire statut et tableau des commandes petite caisse -->
<Annotations Target="SAP__self.CreatePettyCashOrder(SAP__self.PurReqSourceType)">
  <Annotation Term="Common.SideEffects">
    <Record Type="Common.SideEffectsType">
      <PropertyValue Property="TargetProperties">
        <Collection>
          <String>_it/SourceStatus</String>
          <String>_it/SourceCriticality</String>
          <String>_it/FollowOnDocument</String>
        </Collection>
      </PropertyValue>
      <PropertyValue Property="TargetEntities">
        <Collection>
          <NavigationPropertyPath>_it/_PettyCash</NavigationPropertyPath>
        </Collection>
      </PropertyValue>
    </Record>
  </Annotation>
</Annotations>
```

> **ℹ️ Pourquoi c'est indispensable pour la conversion**
> Le résultat de l'action est lu **avant** la sauvegarde : il porte le statut `REQ` et pas encore le numéro de
> commande. La relecture déclenchée par les side effects intervient **après** la sauvegarde et affiche `CONV` et
> le document créé, ou `ERR` et le message.

> **⚠️ À contrôler en recette (J1, point 20)** — les noms de types d'entité (`PurReqSourceType`,
> `SourceOptionType`) sont à relever dans le `$metadata` du service.

---

### H4 — Reprise de l'extension mutualisée `sourcecommon`

Le fragment maquette `apps/sourcecommon/SourceGuidance.fragment.xml` (alerte « aucune source fournisseur : la
commande petite caisse est la seule option ») est lié au modèle V2 et au point d'extension
`BeforeFacet|ZC_ResaPurReqWorklist|Sources`. En V4 :

1. Réécrire le fragment avec des liaisons V4 sur l'entité courante : visible si
   `{= ${SupplierSourceCount} === 0 && ${PettyCashEligible} === 'X' }`.
2. Déclarer une **section personnalisée** dans chaque manifeste de détermination :

```json
"PurReqSourceObjectPage": {
  "options": {
    "settings": {
      "entitySet": "PurReqSource",
      "content": {
        "body": {
          "sections": {
            "SourceGuidance": {
              "template": "zresa.sourcecommon.SourceGuidance",
              "title": "Orientation",
              "position": { "placement": "Before", "anchor": "Sources" }
            }
          }
        }
      }
    }
  }
}
```

3. Conserver le `resourceRoots` `zresa.sourcecommon` et le déploiement mutualisé décrits dans le MO maquettes
   (§6.3) : le fragment reste **commun** aux deux applications, grâce aux noms d'entités identiques (G1).

> **⚠️ À vérifier** — la prise en charge des sections personnalisées par manifeste (`content.body.sections`) en
> SAPUI5 1.96. À défaut, placer l'alerte en **en-tête** via un `UI.DataPoint` supplémentaire (sans code).

---

### H5 — Écrans de création

Aucun code : l'action statique annotée en `#FOR_ACTION` (F3.4) apparaît dans la barre d'outils de la liste, et
Fiori elements génère le dialogue de saisie à partir de l'entité abstraite (D5). La liste restitue l'historique
des besoins saisis avec leur statut et le document créé.

Pour `zlr.alt2creation`, ajouter en side effect sur `CreateReplenishmentOrder` une relecture de la liste
(`TargetEntities` vide sur l'ensemble d'entités) afin d'afficher le statut final après sauvegarde.

> **📸 COPIE D'ÉCRAN N°17** — Alternative 2 : dialogue « Nouvelle commande de réapprovisionnement », aide à la saisie de la source
> *Remplacer cette ligne par :* `![Copie 17](images/RESA-SRC-RAP/capture-17.png)`

> **📸 COPIE D'ÉCRAN N°18** — Alternative 1 : écran de détermination sans bouton de création
> *Remplacer cette ligne par :* `![Copie 18](images/RESA-SRC-RAP/capture-18.png)`

### H6 — Navigation

| Depuis | Vers | Mécanisme |
|---|---|---|
| Page objet — document aval | `PurchaseOrder-displayFactSheet` | `@UI.lineItem` / `@UI.fieldGroup` `type: #WITH_INTENT_BASED_NAVIGATION` sur `FollowOnDocument` |
| Page objet — demande d'achat | `PurchaseRequisition-displayFactSheet` | Idem sur `PurchaseRequisition` |
| Liste | `ResaCockpit-display` | `#FOR_INTENT_BASED_NAVIGATION` en barre d'outils, comme le suivi détaillé |

Les objets sémantiques standard restent à relever (cf. README, « À configurer dans le Launchpad réel »).

### H7 — Déploiement

1. `npm run deploy-test` puis `npm run deploy` dans chaque application.
2. Contrôler les applications BSP et activer les nœuds ICF (`SICF`).
3. Appeler chaque application par son URL directe.

> **📸 COPIE D'ÉCRAN N°19** — SICF : nœuds des quatre applications actifs
> *Remplacer cette ligne par :* `![Copie 19](images/RESA-SRC-RAP/capture-19.png)`

---

## Partie I — Rôles, autorisations et launchpad

### I1 — Objet d'autorisation `ZRESA_PC`

1. `SU21` → classe d'objets `⟨CLASSE_OBJ_AUTH⟩` (existante du projet, ou à créer).
2. Créer l'objet `ZRESA_PC`, texte `Commande petite caisse (réservations)`.
3. Champs : `ACTVT`, `WERKS`.
4. *Activités autorisées* : `01` Créer, `03` Afficher.
5. Enregistrer dans l'ordre workbench.

> **📸 COPIE D'ÉCRAN N°20** — SU21 : objet `ZRESA_PC` et activités autorisées
> *Remplacer cette ligne par :* `![Copie 20](images/RESA-SRC-RAP/capture-20.png)`

### I2 — Propositions SU24

Pour chacun des quatre services publiés (`SU24`, type *TADIR Service*, recherche par nom du groupe de services) :

| Service | Objets proposés |
|---|---|
| `ZUI_RESASRC_ALT1`, `ZUI_RESASRC_ALT2` | `M_BANF_WRK` (03, 02), `M_BEST_WRK` (01), `M_BEST_BSA` (01), `ZRESA_PC` (01) |
| `ZUI_RESAREPL_ALT1` | `M_BANF_WRK` (01, 03) |
| `ZUI_RESAREPL_ALT2` | `M_BANF_WRK` (03), `M_BEST_WRK` (01), `M_BEST_BSA` (01) |

> **⚠️ À vérifier** — le type d'objet TADIR sous lequel un groupe de services OData V4 apparaît en SU24 et PFCG
> dépend du niveau de release : le relever par l'aide à la saisie plutôt que de le saisir.

### I3 — Catalogues, groupes et tuiles

Launchpad Designer (`/UI2/FLPD_CUST`) ou gestionnaire de contenu (`/UI2/FLPCM_CUST`), ordre de customizing.

| Catalogue | Tuile | Intention | Sous-titre |
|---|---|---|---|
| `ZRESA_SRC_TC_ALT1` | Détermination de la source | `ResaSource-determineAll` | Toutes les demandes d'achat |
| `ZRESA_SRC_TC_ALT1` | Créer une demande d'achat | `ResaPurReq-create` | Réapprovisionnement manuel |
| `ZRESA_SRC_TC_ALT2` | Réservations à approvisionner | `ResaSource-determineResa` | Source et petite caisse |
| `ZRESA_SRC_TC_ALT2` | Commande de réapprovisionnement | `ResaReplen-order` | Source choisie à la saisie |

Pour chaque tuile : target mapping de type *Application SAPUI5 Fiori*, ID de composant = ID de l'application,
URL = `/sap/bc/ui5_ui5/sap/<nom BSP>`. Créer un groupe `ZRESA_SRC_TG_ALT1` / `ZRESA_SRC_TG_ALT2` contenant
les tuiles du catalogue.

> **📸 COPIE D'ÉCRAN N°21** — Launchpad Designer : catalogue `ZRESA_SRC_TC_ALT1`, tuiles et target mappings
> *Remplacer cette ligne par :* `![Copie 21](images/RESA-SRC-RAP/capture-21.png)`

### I4 — Rôles PFCG

| Rôle | Menu | Autorisations |
|---|---|---|
| `ZR_RESA_SRC_ALT1` | Catalogue et groupe Alternative 1, services `ZUI_RESASRC_ALT1` et `ZUI_RESAREPL_ALT1` | `M_BANF_WRK` : `ACTVT` 01, 02, 03 · `M_BEST_WRK` : `ACTVT` 01 · `M_BEST_BSA` : `ACTVT` 01, `BSART` = `ZDI5` + types STO · `ZRESA_PC` : `ACTVT` 01, 03 — `WERKS` = périmètre de l'utilisateur |
| `ZR_RESA_SRC_ALT2` | Catalogue et groupe Alternative 2, services `ZUI_RESASRC_ALT2` et `ZUI_RESAREPL_ALT2` | Idem |
| `ZR_RESA_SRC_CUSTO` | Transaction `SM30` | `S_TABU_DIS` sur `⟨GROUPE_AUTH_TABLE⟩` ou `S_TABU_NAM` sur les cinq tables `ZTRESA_…` de customizing — `ACTVT` 02, 03 |

1. Créer le rôle unique, onglet *Menu* : ajouter catalogue et groupe (*SAP Fiori Tile Catalog*,
   *SAP Fiori Tile Group*), puis les services en *Autorisation par défaut*.
2. Onglet *Autorisations* : générer, compléter les valeurs de division (`WERKS`) et de type de document (`BSART`).
3. Générer le profil, affecter l'utilisateur de test.
4. Invalider les caches : `/UI2/INVALIDATE_GLOBAL_CACHES` et vidage du cache navigateur.

> **⚠️ Petite caisse**
> `ZRESA_PC` peut être retiré d'un rôle pour interdire l'achat local à une population donnée : le bouton reste
> visible mais **désactivé** pour cette population, le contrôle étant fait par instance.

> **📸 COPIE D'ÉCRAN N°22** — PFCG : rôle `ZR_RESA_SRC_ALT1`, autorisations
> *Remplacer cette ligne par :* `![Copie 22](images/RESA-SRC-RAP/capture-22.png)`

### I5 — Contrôle de bout en bout

1. Se connecter avec l'utilisateur de test (division A uniquement).
2. Vérifier que seules les tuiles du rôle apparaissent.
3. Vérifier que la liste ne restitue que les postes de la division A.
4. Vérifier qu'un utilisateur sans `ZRESA_PC` voit le bouton petite caisse désactivé.

---

## Partie J — Recette, transport et exploitation

### J1 — Fiche de recette

| N° | Point de contrôle | Résultat attendu | OK / KO |
|---|---|---|---|
| 1 | Paramétrage B3 saisi, aucune valeur `⟨…⟩` restante dans le code | Conforme | ☐ |
| 2 | Tranche `ZRESA_PC` : intervalle `01` présent | Présent | ☐ |
| 3 | Fournisseur présent dans `⟨TABLE_ZC10⟩` avec fiche info : ligne `EDI` | Présente, une seule fois | ☐ |
| 4 | Fournisseur absent de `⟨TABLE_ZC10⟩` | Pas de ligne `EDI` | ☐ |
| 5 | Entrepôt paramétré avec stock : ligne `WHSE`, disponibilité A ou B selon la quantité | Conforme | ☐ |
| 6 | Centre voisin paramétré avec stock : ligne `STOR` | Conforme | ☐ |
| 7 | Poste sous le plafond : ligne `CASH` ; au-dessus : aucune | Conforme | ☐ |
| 8 | Aucun tri par prix ou disponibilité dans le comparatif | Tri par type puis rang | ☐ |
| 9 | Retenir une source : ligne `ZTRESA_SRCSEL` créée, statut « Source choisie » | Conforme | ☐ |
| 10 | Retenir une autre source : ligne mise à jour, une seule option « Retenue » | Conforme | ☐ |
| 11 | Source sans type de document paramétré : message 002, rien d'enregistré | Conforme | ☐ |
| 12 | Convertir, source EDI : CA `ZDI5` créée, DA référencée, statut « Approvisionnement lancé » | Conforme | ☐ |
| 13 | Convertir, entrepôt : commande de transfert du type paramétré, division livreuse = entrepôt | Conforme | ☐ |
| 14 | Convertir, centre voisin : commande de transfert du type paramétré | Conforme | ☐ |
| 15 | Échec BAPI provoqué (ex. fournisseur bloqué) : statut `ERR`, message lisible, pas de commande | Conforme | ☐ |
| 16 | Conversion multiple (3 postes) : 3 commandes, une par poste | Conforme | ☐ |
| 17 | Petite caisse sous le plafond : document `ZPC` numéroté par la tranche, poste soldé | Conforme | ☐ |
| 18 | Petite caisse au-dessus du plafond ou dans une autre devise : messages 008 / 018, rien de créé | Conforme | ☐ |
| 19 | Actions désactivées sur un poste déjà approvisionné | Désactivées | ☐ |
| 20 | Side effects : statut, document aval et comparatif rafraîchis sans rechargement de page | Conforme | ☐ |
| 21 | Alternative 2 : seules les réservations sont listées, y compris en levant tous les filtres | Conforme | ☐ |
| 22 | Alternative 2, création : aide à la saisie de la source filtrée par division et article ; source non candidate rejetée (012) | Conforme | ☐ |
| 23 | Alternative 1, création : DA créée avec le type `⟨TYPE_DA_REAPPRO⟩`, visible ensuite dans la détermination | Conforme | ☐ |
| 24 | Poste ouvert simultanément en ME52N : action refusée (message 001) | Conforme | ☐ |
| 25 | Utilisateur limité à une division : ne voit que ses postes | Conforme | ☐ |
| 26 | Utilisateur sans `M_BEST_BSA` pour le type : conversion désactivée ou refusée (005) | Conforme | ☐ |
| 27 | Utilisateur sans `ZRESA_PC` : petite caisse désactivée | Conforme | ☐ |
| 28 | Cockpit : un poste converti ou soldé en petite caisse n'est plus compté en attente | Conforme | ☐ |
| 29 | Temps de réponse de la liste et de la page objet sur volume réel (question ouverte n°7) | Acceptable | ☐ |
| 30 | Écran de détermination Alternative 1 sans bouton de création | Conforme | ☐ |

> **📸 COPIE D'ÉCRAN N°23** — Page objet après conversion : statut, document aval, message de succès
> *Remplacer cette ligne par :* `![Copie 23](images/RESA-SRC-RAP/capture-23.png)`

> **📸 COPIE D'ÉCRAN N°24** — ME23N : commande créée, référence à la DA
> *Remplacer cette ligne par :* `![Copie 24](images/RESA-SRC-RAP/capture-24.png)`

> **📸 COPIE D'ÉCRAN N°25** — Page objet : commande petite caisse créée
> *Remplacer cette ligne par :* `![Copie 25](images/RESA-SRC-RAP/capture-25.png)`

### J2 — Impact sur l'existant

| Objet existant | Modification |
|---|---|
| `ZI_ResaChainCube` | `FollowOnDocumentType` est aujourd'hui forcé à `ZDI5` : le lire depuis le type réel de la commande (jointure sur l'en-tête de commande d'achat, champ de type de document à relever) pour distinguer CA et commandes de transfert |
| `ZI_ResaSrcEdi`, `ZI_ResaSrcWhse`, `ZI_ResaSrcStore`, `ZI_ResaSrcCash`, `ZI_ResaSourceAvail` (vues classiques) | Remplacées par les view entities de la partie C ; supprimer les anciennes après bascule |
| `ZC_ResaPurReqWorklist`, `ZC_ResaSourceOption`, `ZC_ResaPettyCashOrder` et leurs extensions | Retirées (service V2 `ZCRESASRC_CDS` désenregistré) |
| Cockpit OVP, suivi détaillé, monitoring IDoc | Inchangés |

### J3 — Transport

| Objet | Ordre | Remarque |
|---|---|---|
| Domaines, éléments de données, tables, index | Workbench | — |
| Classe de messages, objet SNRO | Workbench | — |
| Intervalles de numéros | — | Création manuelle par système (décision A3) |
| Groupe de fonctions `ZRESA_SRC_TMG`, dialogues SM30 | Workbench | — |
| Contenu des tables de customizing | **Customizing** | Saisi en développement customizing |
| Vues CDS, DCL, extensions de métadonnées | Workbench | — |
| Behavior definitions, classes | Workbench | — |
| Service definitions et bindings | Workbench | **Publier** les bindings dans chaque système après import (`/IWFND/V4_ADMIN`) |
| Applications BSP | Workbench | Activation ICF à l'arrivée |
| Objet d'autorisation, propositions SU24 | Workbench | — |
| Catalogues, groupes, target mappings, rôles | Customizing | Invalidation des caches à l'arrivée |

**Ordre d'import** : tables et SNRO → CDS d'interface → BO (vues, BDEF, classes) → projections et services →
applications → autorisations et rôles → customizing.

> **⚠️ Après import**
> Publier les quatre groupes de services, créer l'intervalle `ZRESA_PC`, activer les nœuds ICF, invalider les
> caches, rejouer les points 1, 2, 12, 17 et 25 de la fiche de recette.

### J4 — Exploitation

| Sujet | Point de vigilance |
|---|---|
| Performance | `ZI_ResaSourceCount` agrège l'union des sources pour chaque poste listé : imposer un filtre division par défaut dans la variante de la liste ; surveiller par `ST05` / trace SQL |
| Tranche `ZRESA_PC` | Seuil d'avertissement 90 % ; une tranche épuisée provoque un arrêt en sauvegarde |
| Statuts `ERR` | Revue périodique des postes en erreur (filtre `SourceStatus = ERR`) |
| Customizing | Toute nouvelle division doit être couverte par la ligne par défaut ou une ligne propre dans `ZTRESA_SRCDOCTY`, `ZTRESA_REPLCFG`, `ZTRESA_PCLIMIT` |
| Concurrence avec le job ME59N (⑵) | Le verrou sur la DA évite la double conversion ; un poste converti par le job sort de la liste « à traiter » |
| Volumétrie | `ZTRESA_SRCSEL` et `ZTRESA_REPLREQ` croissent avec les DA : prévoir une purge alignée sur l'archivage des DA |
| Évolution des règles | Toute règle de source se modifie en partie C, sans toucher au BO ni aux écrans |

---

## Annexe A — Diagnostic des incidents fréquents

| Symptôme | Cause probable | Action corrective |
|---|---|---|
| La BDEF refuse `strict`, `provider contract` ou l'union | Niveau de release (R6) | Appliquer les replis du §2.3 |
| `late numbering` refusé sur `PettyCash` | Non supporté en managed à ce niveau | Retirer `late numbering` ; dans `CreatePettyCashOrder`, tirer le numéro par `NUMBER_GET_NEXT` et le passer à la création ; supprimer `adjust_numbers` (numéros perdus possibles en cas d'échec) |
| Dump `RAP_…` sur `COMMIT` | Commit dans une BAPI ou un module appelé | Rechercher l'appel ; les BAPI de création ne commitent pas, un module appelé en complément si |
| Conversion : statut reste « Conversion demandée » à l'écran | Side effects absents ou type d'entité erroné | H3 ; vérifier les noms de types dans `$metadata` |
| Conversion : statut `ERR`, message d'unité ou de date | Format attendu par la BAPI (R7) | Tests SE37 et adaptation de `ZCL_RESA_SRC_PO` |
| Aucune option de source pour un poste | Customizing absent ou `⟨TABLE_ZC10⟩` non alimentée | Contrôler `ZI_ResaSrcCandidate` pour la division et l'article |
| Fournisseur en double dans le comparatif | Plusieurs organisations d'achat | Filtrer par organisation d'achat (C1) |
| Bouton petite caisse toujours désactivé | Plafond non paramétré, devise différente ou `ZRESA_PC` manquant | `ZTRESA_PCLIMIT`, rôle |
| Liste vide pour l'utilisateur | DCL `M_BANF_WRK` sans la division | Compléter le rôle |
| Message 001 systématique | Verrou non libéré ou objet de verrou erroné | `SM12` ; vérifier R4 |
| Service introuvable depuis l'application | Binding non publié dans le système | `/IWFND/V4_ADMIN`, publier |

---

## Annexe B — Correspondance maquette V2 → RAP

| Maquette (`ZCRESASRC_CDS`) | Paramètres maquette | RAP | Paramètres RAP |
|---|---|---|---|
| `AssignSource` | `PurchaseRequisition`, `PurchaseRequisitionItem`, `SourceOptionId` | `SourceOption~SelectSource` | Aucun (instance = option) |
| `ConvertToPurchaseOrder` | idem | `PurReqSource~ConvertToPurchaseOrder` | Aucun (source retenue) |
| `CreatePettyCashOrder` | poste, `LocalSupplierName`, `Amount` | `PurReqSource~CreatePettyCashOrder` | `ZD_ResaPettyCashParam` (+ `Currency`) |
| `CreatePurchaseRequisition` | `Plant`, `Material`, `ItemText`, `Quantity`, `RequestedDate` | `ReplenRequest~CreatePurchaseRequisition` (statique) | `ZD_ResaReplenPRParam` (+ `BaseUnit`) |
| `CreateReplenishmentOrder` | idem + `SourceType`, `SourceId` | `ReplenRequest~CreateReplenishmentOrder` (statique) | `ZD_ResaReplenPOParam` |
| Entité `ZC_ResaPurReqWorklist` | clé DA + poste | `PurReqSource` | idem |
| Entité `ZC_ResaSourceOption` | clé `SourceOptionId` concaténée | `SourceOption` | clé composée DA, poste, type, identifiant |
| Entité `ZC_ResaPettyCashOrder` | clé `PettyCashOrder` | `PettyCash` | clé DA, poste, n° `ZPC` |
| `SourceStatus` `TODO` / `SEL` / `CONV` | — | + `REQ`, `ERR` | — |

---

## Annexe C — Paramètres à renseigner

| Paramètre | Utilisé en | À fournir par | Valeur |
|---|---|---|---|
| `⟨TABLE_ZC10⟩` | C1 | Équipe interface | … |
| `⟨CHAMP_ZC10_FOURNISSEUR⟩`, `⟨CHAMP_ZC10_ARTICLE⟩`, `⟨CHAMP_ZC10_DISPO⟩` (+ division éventuelle) | C1 | Équipe interface | … |
| Correspondance des codes de disponibilité ZC10 avec A / B / C | C4 | Métier | … |
| `⟨OBJET_VERROU_EBAN⟩` et paramètres | E1 | Technique (R4) | … |
| `⟨CHAMP_UNITE_DE_PRIX_DA⟩` et champs R1 | C4, D1 | Technique | … |
| Vue et champ de stock, stock libre ou ATP | C2 | Technique + métier (R3) | … |
| `⟨EKORG_EDI⟩`, `⟨EKORG_STO⟩` | B3 | Fonctionnel MM | … |
| `⟨TYPE_STO_ENTREPOT⟩`, `⟨TYPE_STO_VOISIN⟩` | B3 | Fonctionnel MM | … |
| `⟨TYPE_DA_REAPPRO⟩`, `⟨EKGRP_REAPPRO⟩` | B3 | Fonctionnel MM | … |
| `⟨PLAFOND_PC⟩`, `⟨DEVISE_PC⟩` (par division ou défaut) | B3 | Métier | … |
| Centres voisins et entrepôts par division (rang, délai) | B3 | Métier / supply chain | … |
| `⟨PC_NUM_DEBUT⟩`, `⟨PC_NUM_FIN⟩` | A3 | Projet | … |
| `⟨GROUPE_AUTH_TABLE⟩` | B2, I4 | Sécurité | … |
| `⟨CLASSE_OBJ_AUTH⟩` | I1 | Sécurité | … |

---

## Annexe D — Index des copies d'écran

| N° | Chapitre | Contenu attendu |
|---|---|---|
| 01 à 02 | Chapitre 2 | Relevés R1 et R4 |
| 03 à 04 | Partie A | Tables applicatives, tranche de numéros |
| 05 à 07 | Partie B | Tables de customizing, maintenance, paramétrage |
| 08 à 09 | Partie C | Sources candidates, options par poste |
| 10 | Partie D | Behavior definition |
| 11 | Partie E | Classes d'implémentation |
| 12 | Partie F | Extension de métadonnées |
| 13 à 15 | Partie G | Binding, publication, preview |
| 16 à 19 | Partie H | Génération, écrans, ICF |
| 20 à 22 | Partie I | Objet d'autorisation, catalogue, rôle |
| 23 à 25 | Partie J | Recette : conversion, commande, petite caisse |

---

## Annexe E — Historique des versions

| Version | Date | Auteur | Nature des modifications |
|---|---|---|---|
| 1.0 | … | … | Création du document |
| | | | |
