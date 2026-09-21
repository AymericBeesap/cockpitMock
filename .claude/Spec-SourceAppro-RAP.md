# Mode opératoire — Détermination de la source d'approvisionnement en RAP

## Une seule application spécifique, à côté des tuiles Fiori standard

| Attribut | Valeur |
|---|---|
| Référence du document | MO-SRCAPPRO-RAP-2021FPS02-v2.0 |
| Documents liés | [MO Cockpit réservations](Spec.md) · [archive : arbitrage des deux alternatives](archive/Spec-SourceAppro.md) · [archive : MO RAP v1](archive/Spec-SourceAppro-RAP-v1.md) |
| Objets créés | 1 table, 5 éléments de données, 1 classe de messages, 1 business object RAP, 1 projection, 1 service OData V4, 1 application Fiori elements V4, 1 rôle |
| Périmètre | Liste des postes de demande d'achat sans source d'approvisionnement ; choix de la source dans une pop-up ; affectation de la source au poste de DA |
| Architecture | 100 % ABAP — RAP managed avec sauvegarde non managée, OData V4, Fiori elements V4, **sans draft** |
| Version produit | SAP S/4HANA 2021 FPS02 — SAPUI5 1.96 |
| Package | `ZRESA_SRC` |
| Outils | Eclipse + ABAP Development Tools · VS Code + SAP Fiori tools · SAP GUI |
| Auteur | … |
| Vérifié par | … |
| Date de rédaction | … |
| Statut | Version de travail |

> **Convention de ce document**
> - Chaque emplacement de copie d'écran est signalé par un bloc `📸 COPIE D'ÉCRAN N°XX`. Déposer les
>   images dans `images/RESA-SRC-RAP/`.
> - Toute valeur **non confirmée** est écrite `⟨ENTRE_CHEVRONS⟩` et reprise dans
>   l'[annexe C](#annexe-c--paramètres-à-renseigner). Le code qui en contient ne s'active pas tant
>   qu'elles ne sont pas remplacées : c'est volontaire.
> - Les encadrés **⚠️ À vérifier** signalent un nom de champ standard ou une capacité RAP à
>   contrôler dans le système avant activation.
> - Les objets sont livrés en fichiers texte dans [../abap/](../abap/), un fichier par objet, à
>   recopier dans ADT.

---

## Sommaire

- [1. Objet et décisions de conception](#1-objet-et-décisions-de-conception)
- [2. Prérequis et relevés](#2-prérequis-et-relevés)
- [3. Architecture](#3-architecture)
- [Partie A — Persistance](#partie-a--persistance)
- [Partie B — Vues CDS et entité personnalisée](#partie-b--vues-cds-et-entité-personnalisée)
- [Partie C — Business object](#partie-c--business-object)
- [Partie D — Implémentation ABAP](#partie-d--implémentation-abap)
- [Partie E — Projection, service et application](#partie-e--projection-service-et-application)
- [Partie F — Rôles, launchpad et tuiles standard](#partie-f--rôles-launchpad-et-tuiles-standard)
- [Partie G — Recette, transport et exploitation](#partie-g--recette-transport-et-exploitation)
- [Annexe A — Diagnostic des incidents fréquents](#annexe-a--diagnostic-des-incidents-fréquents)
- [Annexe B — Ce que la v2 abandonne par rapport à la v1](#annexe-b--ce-que-la-v2-abandonne-par-rapport-à-la-v1)
- [Annexe C — Paramètres à renseigner](#annexe-c--paramètres-à-renseigner)
- [Annexe D — Index des copies d'écran](#annexe-d--index-des-copies-décran)
- [Annexe E — Historique des versions](#annexe-e--historique-des-versions)

---

## 1. Objet et décisions de conception

### 1.1 Objet

La v1 de ce mode opératoire décrivait la réalisation RAP d'un socle complet de détermination de la
source : quatre applications pour arbitrer deux alternatives, huit tables dont cinq de customizing,
des vues CDS reconstituant les quatre familles de sources, la commande petite caisse et la création
de besoins de réapprovisionnement.

L'arbitrage a tranché autrement, et beaucoup plus simplement :

- **le cockpit s'appuie sur les tuiles Fiori standard** de demande d'achat et de commande d'achat ;
  rien n'est développé pour afficher, créer ou convertir une DA ;
- **une seule application spécifique** reste nécessaire : la liste des postes de DA pour lesquels
  il manque la source d'approvisionnement, avec une pop-up de choix parmi les sources disponibles ;
- **les sources ne sont pas calculées par cette application** : elles sont rendues par un
  programme existant de S/4 (`⟨PROGRAMME_SOURCES⟩`), appelé à l'exécution. Il n'y a donc aucune
  table de customizing de sources, aucune union CDS de familles de sources, aucune règle métier
  dupliquée.

Le périmètre passe de 8 tables, 2 business objects, 4 services et 4 applications à **1 table,
1 business object, 1 service, 1 application**.

### 1.2 Décisions retenues

| Sujet | Décision | Conséquence |
|---|---|---|
| Périmètre du cockpit | **Tuiles standard** pour la DA et la commande d'achat ; une seule tuile Z | L'Overview Page et les quatre applications de maquette sont abandonnées |
| Origine des sources | **Programme / classe ABAP de S/4**, appelé à chaque ouverture de la pop-up | `ZIF_RESA_SRC_PROVIDER` + `ZCL_RESA_SRC_PROVIDER` ; aucun customizing |
| Restitution des sources | **Entité personnalisée** RAP (`ZI_ResaSourceOption`) avec requête non managée | Rien n'est stocké : la liste est toujours à jour |
| Pop-up | **Aide à la saisie sur le paramètre de l'action**, 100 % annotations | Aucun JavaScript ; les colonnes sont les `@UI.lineItem` de l'entité personnalisée |
| Effet du choix | **La source est écrite dans le poste de DA standard** (`BAPI_PR_CHANGE`) | La conversion en commande reste faite par le standard (ME59N, Manage Purchase Orders) |
| Trace | Une ligne par poste dans `ZTRESA_SRCSEL` : source retenue, prix et délai au moment du choix, résultat de l'affectation | Audit du choix, et reprise des refus |
| Draft | **Sans draft** | L'action écrit directement ; verrou pessimiste sur la DA |
| Transaction | **Aucun COMMIT hors RAP** | `BAPI_PR_CHANGE` appelé en phase de sauvegarde ; un rollback RAP annule tout |
| Autorisations | Objet **standard** `M_BANF_WRK` (03 affichage, 02 affectation) | Aucun objet d'autorisation Z |
| Règle de proposition | **Aucune proposition automatique** (inchangé depuis la v1) : comparatif, choix manuel | Le rang rendu par le programme est affiché, il n'ordonne rien d'autorité |
| Petite caisse, réapprovisionnement | **Hors périmètre** | Voir [annexe B](#annexe-b--ce-que-la-v2-abandonne-par-rapport-à-la-v1) |

### 1.3 Le point dur, énoncé d'emblée

Affecter une source à un poste de DA existant n'est pas symétrique selon le type de source :

- **source fournisseur** — fournisseur fixe, fiche info, organisation d'achat : le standard
  accepte la modification sur un poste existant ;
- **source entrepôt ou centre voisin** — division livreuse : la modification suppose une
  **catégorie de poste `U`** (transfert). Un poste créé en catégorie standard ne la prend pas et le
  BAPI refuse.

Ce mode opératoire **ne masque pas ce refus** : il est contrôlé avant écriture (mode simulation du
BAPI dans l'action), affiché à l'acheteur, et si le refus survient malgré tout en sauvegarde, il est
enregistré dans `ZTRESA_SRCSEL` (statut `ERR` + message) et le poste **reste dans la liste de
travail**, en rouge, avec le message du standard. La création d'un poste de transfert à la place du
poste refusé est **hors périmètre** : c'est un arbitrage à mener avec le fonctionnel MM
(relevé [R4](#23-relevés-à-faire-avant-de-coder)).

### 1.4 Hors périmètre

- Détermination elle-même : `⟨PROGRAMME_SOURCES⟩` existe et n'est pas modifié.
- Création d'une demande d'achat, conversion en commande : tuiles standard.
- Commande petite caisse, besoin de réapprovisionnement manuel, customizing des entrepôts et
  centres voisins (v1, abandonnés — annexe B).
- Intégration des réservations par IDoc `Z_CREA_PR` (supposée en place, cf. [MO Cockpit](Spec.md)).
- Création d'un poste de transfert quand la division livreuse est refusée (§1.3).

---

## 2. Prérequis et relevés

### 2.1 Prérequis fonctionnels

| Élément | Exigence | Responsable |
|---|---|---|
| Programme de détermination | Existe, appelable en synchrone, rend une liste de sources pour un besoin | Équipe S/4 — `⟨PROGRAMME_SOURCES⟩` |
| Champ de réservation | Présent dans la DA et exposé dans `I_PurchaseRequisitionItem` (`ZZReservation`) | Déjà traité par le MO cockpit |
| Tuiles standard | Applications de gestion des DA et des commandes d'achat activées et affectées aux acheteurs | Fonctionnel MM + Basis |
| Catégorie de poste des DA de réservation | Connue, et décision sur le sort des sources « division livreuse » (§1.3) | Fonctionnel MM |

### 2.2 Prérequis techniques

| Élément | Exigence |
|---|---|
| Plateforme | SAP S/4HANA 2021 FPS02 (ABAP 7.56) |
| ADT | Version à jour, compatible 7.56 (éditeurs *Behavior Definition*, *Service Binding*) |
| VS Code | SAP Fiori tools, générateur *List Report Page* OData V4 |
| Autorisations développeur | `S_DEVELOP`, `S_TRANSPRT`, SU21 (lecture), PFCG, `/IWFND/V4_ADMIN` |
| Package / transport | Package `ZRESA_SRC`, un ordre workbench |

### 2.3 Relevés à faire avant de coder

Ne rien deviner : chaque ligne conditionne le code des parties A à E.

| N° | Relevé | Où | Utilisé en |
|---|---|---|---|
| R1 | Éléments réels de `I_PurchaseRequisitionItem` caractérisant l'**absence de source** : `FixedSupplier`, `PurchasingInfoRecord`, `SupplyingPlant`, `PurchaseContract`, `PurchaseOrder`, indicateurs de suppression et de clôture, `DeliveryDate`, `PurchaseRequisitionPrice`, `ZZReservation` | ADT, *Open Data Preview* + *Element Info* | B1 |
| R2 | Nom et signature de `⟨PROGRAMME_SOURCES⟩` : paramètres d'entrée (division, article, quantité, unité, date), structure de sortie, codes de type de source et de disponibilité | Équipe S/4 | D1 |
| R3 | Objet de verrouillage de `EBAN` et noms de ses paramètres | SE11 → *Objets de verrouillage*, recherche sur `EBAN` | D3 |
| R4 | Ce que `BAPI_PR_CHANGE` accepte sur un poste existant, **par type de source** ; existence du paramètre `TESTRUN` ; noms de champs de `BAPIMEREQITEMIMP` / `BAPIMEREQITEMX` | SE37 en exécution test, puis fonctionnel MM | D4, §1.3 |
| R5 | **Pré-alimentation des paramètres d'action depuis le contexte** et **aide à la saisie sur paramètre d'action** en Fiori elements V4 sous SAPUI5 1.96 | Sandbox de l'application, après activation du service | E1 |
| R6 | Capacités RAP du système : `strict`, `internal update`, `provider contract transactional_query`, entité personnalisée `@ObjectModel.query.implementedBy`, addition `MESSAGE` sur `cx_rap_query_provider` | Objet de test dans `$TMP` | B, C, D |
| R7 | Identifiants et intentions réels des tuiles standard : DA, commande d'achat, conversion automatique (ME59N) | Fiori Apps Reference Library + catalogues achats | F |

> **⚠️ R5 — le seul relevé qui peut changer l'écran.** La pop-up est une aide à la saisie sur le
> paramètre `SourceId` de l'action, filtrée sur le poste de DA. Pour que ce filtrage fonctionne, les
> deux paramètres de contexte (`PurchaseRequisition`, `PurchaseRequisitionItem`) doivent être
> alimentés par le contexte de la ligne sélectionnée : ils portent volontairement le nom des
> propriétés de l'entité pour que Fiori elements les reconnaisse. ABAP 7.56 n'offre pas encore de
> mécanisme RAP de valeurs par défaut des paramètres d'action ; c'est donc un comportement de la
> couche UI à contrôler dans le système.
>
> **Replis, par ordre de préférence**, si la pop-up n'est pas alimentée :
> 1. remplacer l'aide à la saisie par une **sous-section de page objet** listant les sources, avec
>    une action de ligne « Retenir cette source » — l'entité personnalisée, le business object et
>    l'action restent identiques, seules les annotations changent ;
> 2. fragment UI5 personnalisé ouvrant un `Dialog` sur la même entité.

> **📸 COPIE D'ÉCRAN N°01** — ADT : aperçu de `I_PurchaseRequisitionItem`, éléments relevés en R1
> *Remplacer cette ligne par :* `![Copie 01](images/RESA-SRC-RAP/capture-01.png)`

> **📸 COPIE D'ÉCRAN N°02** — SE37 : signature de `⟨PROGRAMME_SOURCES⟩` (R2)
> *Remplacer cette ligne par :* `![Copie 02](images/RESA-SRC-RAP/capture-02.png)`

> **📸 COPIE D'ÉCRAN N°03** — SE11 : objet de verrouillage de `EBAN` et ses paramètres (R3)
> *Remplacer cette ligne par :* `![Copie 03](images/RESA-SRC-RAP/capture-03.png)`

---

## 3. Architecture

### 3.1 Vue d'ensemble

```
EXISTANT S/4     I_PurchaseRequisitionItem            ⟨PROGRAMME_SOURCES⟩
                            │                                  │  appel synchrone
INTERFACE (B)    ZI_ResaPurReqNoSource                 ZCL_RESA_SRC_PROVIDER
                 postes sans source, non convertis             │  (ZIF_RESA_SRC_PROVIDER)
                            │                          ZCL_RESA_SRC_QUERY
TRACE (A)        ZTRESA_SRCSEL                                 │  (IF_RAP_QUERY_PROVIDER)
                            │                          ZI_ResaSourceOption  ← entité personnalisée
BO (C)           ZR_ResaPurReqSource                           ↑      = contenu de la pop-up
                 managed with unmanaged save          @Consumption.valueHelpDefinition
                 action SelectSource(ZD_ResaSourceSelParam)    │
PROJECTION (E)   ZC_ResaPurReqSource (+ extension de métadonnées)
SERVICE (E)      ZUI_RESASRC  →  ZUI_RESASRC_O4 (OData V4 - UI)
APPLICATION (E)  apps/srcappro — zlr.srcappro, intention ResaSource-determine
SAUVEGARDE (D)   ZCL_RESA_SRC_PRUPDATE → BAPI_PR_CHANGE, sans COMMIT
                            │
                 la DA porte sa source → le poste quitte la liste de travail
                 → conversion par les tuiles standard (ME59N, Manage Purchase Orders)
```

### 3.2 Pourquoi « managed with unmanaged save »

| Contrainte | Réponse |
|---|---|
| La racine est le **poste de DA standard** ; la ligne de trace n'existe pas tant que rien n'est retenu | La sauvegarde managée ne sait faire qu'un `UPDATE` d'une ligne existante ; la sauvegarde non managée fait un `MODIFY` |
| La source doit être **réellement écrite** dans la DA par un BAPI | Appel dans `save_modified`, seul endroit où une mise à jour hors BO est légitime |
| Le tampon transactionnel, l'action, le contrôle des fonctionnalités et des autorisations restent standard | Partie « managed » conservée |

### 3.3 Cycle de vie d'un poste

| `SelectionStatus` | Libellé | Atteint par | Suite |
|---|---|---|---|
| `TODO` | À traiter | Poste de DA ouvert sans source | Retenir une source |
| `ERR` | Affectation refusée par la demande d'achat | `SelectSource`, refus du standard en sauvegarde | Reste dans la liste, en rouge, message affiché ; retenir une autre source |
| — | (absent de la liste) | `SelectSource` réussie : la DA porte une source | Conversion par le standard |

La liste de travail n'a **pas d'état vert** : un poste servi disparaît. C'est ce qui la rend
utilisable comme liste de travail, et c'est le seul filtre métier de l'application.

---

## Partie A — Persistance

### A1. Éléments de données

À créer dans ADT (pas de représentation texte). Domaine et élément de données de même nom.

| Nom | Type | Valeurs fixes / usage |
|---|---|---|
| `ZRESA_SRCTYPE` | `CHAR(4)` | `EDI` Fournisseur · `WHSE` Entrepôt · `STOR` Centre voisin |
| `ZRESA_SRCID` | `CHAR(10)` | Identifiant de la source : fournisseur, entrepôt ou division voisine |
| `ZRESA_SRCNAME` | `CHAR(60)` | Désignation de la source |
| `ZRESA_SELSTAT` | `CHAR(4)` | `SEL` Source retenue · `ERR` Affectation refusée |
| `ZRESA_UPDMSG` | `CHAR(220)` | Message du BAPI en cas de refus |

> Les valeurs fixes du domaine `ZRESA_SRCTYPE` doivent couvrir les codes réellement rendus par
> `⟨PROGRAMME_SOURCES⟩` (relevé R2). En ajouter un ne demande aucune modification de code : le
> libellé affiché est calculé dans `ZCL_RESA_SRC_QUERY`, qui retombe sur le code s'il est inconnu.

### A2. Table `ZTRESA_SRCSEL`

Source : [../abap/tables/ZTRESA_SRCSEL.tabl.asddls](../abap/tables/ZTRESA_SRCSEL.tabl.asddls).

Clé `MANDT` / `BANFN` / `BNFPO` — une ligne par poste de demande d'achat. Classe de livraison `A`,
`#NOT_EXTENSIBLE`, `dataMaintenance: #RESTRICTED`.

La table ne stocke **pas les sources** : seulement le choix retenu, ses caractéristiques au moment
du choix (prix, délai — pour l'audit, puisqu'elles seront recalculées différemment demain), les
champs d'affectation portés dans la DA, le statut et le message du standard.

### A3. Classe de messages `ZRESA_SRC`

| N° | Texte | Variables |
|---|---|---|
| 001 | Source &1 &2 inconnue pour ce poste | type, identifiant |
| 002 | Détermination des sources indisponible pour la division &1 / l'article &2 | division, article |
| 003 | Demande d'achat &1 verrouillée par &2 | DA, utilisateur |
| 004 | Poste de demande d'achat non renseigné : aucune source ne peut être proposée | — |
| 005 | Retenir une source d'approvisionnement | — |
| 006 | Affectation de la source refusée : &1 | message du standard |

---

## Partie B — Vues CDS et entité personnalisée

### B1. `ZI_ResaPurReqNoSource` — la liste de travail

Source : [../abap/cds/ZI_ResaPurReqNoSource.asddls](../abap/cds/ZI_ResaPurReqNoSource.asddls).

Vue d'interface sur `I_PurchaseRequisitionItem`. Le `where` est **le cœur fonctionnel de
l'application** : un poste est dans la liste s'il n'a ni fournisseur fixe, ni fiche info, ni
division livreuse, ni contrat, s'il n'est pas converti, ni supprimé, ni clôturé.

> **⚠️ À vérifier (R1)** — les noms d'éléments utilisés dans le `where` sont les noms attendus de
> `I_PurchaseRequisitionItem`. Les contrôler un par un dans ADT avant activation : c'est la seule
> partie du code dont une erreur ne se voit pas (la liste serait simplement fausse).

### B2. `ZI_ResaSourceOption` — le contenu de la pop-up

Source : [../abap/cds/ZI_ResaSourceOption.asddls](../abap/cds/ZI_ResaSourceOption.asddls).

Entité personnalisée : `@ObjectModel.query.implementedBy: 'ABAP:ZCL_RESA_SRC_QUERY'`. Les lignes ne
sont pas lues en base, elles sont produites à l'exécution.

Clé : poste de DA + type de source + identifiant de source. Le poste **doit** être en filtre : hors
contexte, la classe de requête lève le message 004 plutôt que de rendre une liste vide, qui se
lirait « aucune source disponible » — ce n'est pas la même information.

Les `@UI.lineItem` de cette entité **dessinent les colonnes de la pop-up** : type de source,
identifiant, désignation, disponibilité (avec criticité), quantité disponible, prix net, délai,
rang. `@UI.selectionField` sur le type de source donne le filtre de la boîte de dialogue.

### B3. `ZD_ResaSourceSelParam` — le paramètre de l'action, et la pop-up

Source : [../abap/cds/ZD_ResaSourceSelParam.asddls](../abap/cds/ZD_ResaSourceSelParam.asddls).

Entité abstraite à quatre champs : deux de contexte (`PurchaseRequisition`,
`PurchaseRequisitionItem`) et deux de choix (`SourceType`, `SourceId`).

C'est l'annotation `@Consumption.valueHelpDefinition` sur `SourceId`, **et elle seule**, qui produit
la pop-up : `additionalBinding` transmet le poste en `#FILTER` et rapatrie le type de source retenu
en `#RESULT`. Aucun code d'interface utilisateur n'est écrit.

### B4. Ordre d'activation

`ZI_ResaPurReqNoSource` → `ZI_ResaSourceOption` → `ZCL_RESA_SRC_QUERY` → `ZD_ResaSourceSelParam`.
L'entité personnalisée s'active avant sa classe de requête, qui la référence comme type de données.

---

## Partie C — Business object

### C1. Vue racine

Source : [../abap/cds/ZR_ResaPurReqSource.asddls](../abap/cds/ZR_ResaPurReqSource.asddls).

`ZI_ResaPurReqNoSource` en jointure externe avec `ztresa_srcsel` : la lecture vient du standard,
l'écriture de la table Z. `SelectionStatus`, son libellé et sa criticité sont calculés — la vue
n'expose pas le code de statut brut de la table.

### C2. Définition de comportement

Source : [../abap/bo/ZR_ResaPurReqSource.bdef](../abap/bo/ZR_ResaPurReqSource.bdef).

```
managed with unmanaged save implementation in class zbp_r_resapurreqsource unique;
strict;

define behavior for ZR_ResaPurReqSource alias PurReqItem
lock master unmanaged
authorization master ( instance )
etag master LastChangedAt
{
  internal update;
  action ( features : instance, authorization : instance )
    SelectSource parameter ZD_ResaSourceSelParam result [1] $self;
}
```

`internal update` : l'action met à jour l'instance par EML en mode local, mais rien n'est exposé
dans le service. Vu d'OData, ce business object est en **lecture seule et n'offre qu'une action** —
ni création, ni modification, ni suppression.

### C3. Contrôle d'accès

Source : [../abap/dcl/ZR_RESAPURREQSOURCE.asdcls](../abap/dcl/ZR_RESAPURREQSOURCE.asdcls) —
`aspect pfcg_auth( M_BANF_WRK, WERKS, ACTVT = '03' )` pour l'affichage. L'activité 02, exigée pour
affecter une source, est contrôlée à l'instance (partie D).

---

## Partie D — Implémentation ABAP

### D1. Appel du programme de détermination

- [../abap/classes/ZIF_RESA_SRC_PROVIDER.intf.abap](../abap/classes/ZIF_RESA_SRC_PROVIDER.intf.abap) —
  `get_sources( )` pour la pop-up, `get_source( )` pour relire la source retenue à la validation.
- [../abap/classes/ZCL_RESA_SRC_PROVIDER.clas.abap](../abap/classes/ZCL_RESA_SRC_PROVIDER.clas.abap) —
  l'appel réel, avec `get_instance( )` / `set_instance( )` pour injecter un double en test.

Deux règles de conception dans cette classe :

1. **un appel en échec n'est jamais silencieux** — il lève le message 002, jamais une table vide ;
2. **une source disparue entre l'ouverture de la pop-up et la validation** lève le message 001 :
   la pop-up a pu rester ouverte plusieurs minutes.

### D2. Classe de requête de l'entité personnalisée

Source : [../abap/classes/ZCL_RESA_SRC_QUERY.clas.abap](../abap/classes/ZCL_RESA_SRC_QUERY.clas.abap).

`IF_RAP_QUERY_PROVIDER~select` : extraction des filtres, lecture du poste dans
`ZI_ResaPurReqNoSource` pour en déduire le besoin, appel du fournisseur, filtre sur le type de
source, `$count`, `$skip` / `$top`. Le programme de détermination est interrogé **une seule fois**,
sur le besoin complet ; le filtre de la boîte de dialogue s'applique au résultat.

### D3. Verrou

`lock` implémente un `ENQUEUE` sur le poste de demande d'achat (`⟨OBJET_VERROU_EBAN⟩`, relevé R3).
Sans draft, deux acheteurs ne doivent pas retenir deux sources différentes sur le même poste.
`cleanup_finalize` libère le verrou.

### D4. Action, et répartition des contrôles

Source : [../abap/classes/ZBP_R_RESAPURREQSOURCE.clas.abap](../abap/classes/ZBP_R_RESAPURREQSOURCE.clas.abap).

| Phase | Ce qui s'y fait | Peut afficher un message ? |
|---|---|---|
| `get_instance_features` | Bouton désactivé si le poste n'a ni division ni article (texte libre) : la pop-up serait vide | — |
| `get_instance_authorizations` | `M_BANF_WRK` activité 02 sur la division du poste | oui (RAP) |
| `lock` | Verrou pessimiste sur la DA | oui |
| **`selectsource`** | Source obligatoire (005), relecture de la source (001), **simulation de l'affectation par `BAPI_PR_CHANGE` en mode `TESTRUN`** puis mise à jour de l'instance | **oui — c'est la seule phase où un refus est affichable** |
| `save_modified` | Affectation réelle (sans `COMMIT`), `MODIFY ztresa_srcsel` | **non** — d'où le statut `ERR` et le message en base |

C'est la raison d'être du mode simulation : la phase de sauvegarde RAP ne peut pas rejeter, donc
tout ce qui peut être contrôlé l'est avant. Le chemin `ERR` reste un filet de sécurité pour un refus
qui n'apparaîtrait qu'au passage réel.

Le tampon local `lcl_src_buffer` transporte la source complète de l'action vers la sauvegarde, qui a
besoin des champs d'affectation que la vue du business object n'expose pas — cela évite un second
appel au programme de détermination.

### D5. Mise à jour de la demande d'achat

Source : [../abap/classes/ZCL_RESA_SRC_PRUPDATE.clas.abap](../abap/classes/ZCL_RESA_SRC_PRUPDATE.clas.abap).

Enveloppe de `BAPI_PR_CHANGE`, appelée en simulation puis en réel. **Aucun
`BAPI_TRANSACTION_COMMIT`, aucun `COMMIT WORK`, aucun `ROLLBACK WORK`** : la transaction appartient
à RAP, qui valide ou annule l'ensemble — y compris la mise à jour du BAPI, enregistrée en tâche de
mise à jour et déclenchée par le `COMMIT` de RAP.

> **⚠️ À vérifier (R4)** — existence du paramètre `TESTRUN`, noms de champs de
> `BAPIMEREQITEMIMP` / `BAPIMEREQITEMX`, et surtout ce que le standard accepte par type de source
> (§1.3).

---

## Partie E — Projection, service et application

### E1. Projection et annotations

- [../abap/cds/ZC_ResaPurReqSource.asddls](../abap/cds/ZC_ResaPurReqSource.asddls) —
  `provider contract transactional_query`, `@Metadata.allowExtensions: true`,
  `@ObjectModel.semanticKey`.
- [../abap/cds/ZC_ResaPurReqSource.asddlxs](../abap/cds/ZC_ResaPurReqSource.asddlxs) — en-tête,
  champs de sélection, colonnes, variante de présentation (postes les plus anciens d'abord), deux
  groupes de champs pour la page objet, et le bouton `#FOR_ACTION` `SelectSource` dans la barre
  d'outils de la liste comme dans le pied de page objet.
- [../abap/bo/ZC_ResaPurReqSource.bdef](../abap/bo/ZC_ResaPurReqSource.bdef) — `use action SelectSource`,
  et rien d'autre.
- [../abap/dcl/ZC_RESAPURREQSOURCE.asdcls](../abap/dcl/ZC_RESAPURREQSOURCE.asdcls) —
  `inheriting conditions from entity ZR_ResaPurReqSource`.

Une seule tuile, donc une seule projection et une seule extension de métadonnées : l'« écart
assumé » de la maquette (des boutons de création apparaissant dans l'écran de détermination parce
que quatre applications partageaient un service) **n'existe plus**.

### E2. Service

- [../abap/srv/ZUI_RESASRC.srvd](../abap/srv/ZUI_RESASRC.srvd) — expose `ZC_ResaPurReqSource as
  PurReqItem` et `ZI_ResaSourceOption as SourceOption`.
- Service binding `ZUI_RESASRC_O4`, type **OData V4 - UI**, à créer dans ADT, puis *Publish*.
- Enregistrement dans `/IWFND/V4_ADMIN` si le système l'exige (Gateway embedded : la publication du
  binding suffit en général).

URI du service : `/sap/opu/odata4/sap/zui_resasrc_o4/srvd/sap/zui_resasrc/0001/`.

> **📸 COPIE D'ÉCRAN N°04** — ADT : *Service Binding* `ZUI_RESASRC_O4` publié, avec l'aperçu
> *Preview* de `PurReqItem`
> *Remplacer cette ligne par :* `![Copie 04](images/RESA-SRC-RAP/capture-04.png)`

### E3. Application

Dossier [../apps/srcappro/](../apps/srcappro/) — List Report Fiori elements V4, `id: zlr.srcappro`,
intention `ResaSource-determine`, `minUI5Version 1.96.0`, entité `PurReqItem`, application BSP
`ZRESA_SRC_APP`.

Le dossier `webapp/localService/ZUI_RESASRC/` contient une copie locale des métadonnées V4 et des
données de démonstration : l'application **tourne sans S/4**, pop-up comprise, ce qui permet de
valider l'ergonomie avant d'avoir le moindre objet activé. Le fichier `data/PurReqItem.js` reproduit
le comportement de l'action, refus du standard inclus.

> **📸 COPIE D'ÉCRAN N°05** — l'application : liste des postes sans source
> *Remplacer cette ligne par :* `![Copie 05](images/RESA-SRC-RAP/capture-05.png)`

> **📸 COPIE D'ÉCRAN N°06** — la pop-up des sources disponibles, ouverte depuis le champ
> « Source retenue » de la boîte de dialogue de l'action
> *Remplacer cette ligne par :* `![Copie 06](images/RESA-SRC-RAP/capture-06.png)`

> **📸 COPIE D'ÉCRAN N°07** — un poste refusé par le standard : statut rouge et message
> *Remplacer cette ligne par :* `![Copie 07](images/RESA-SRC-RAP/capture-07.png)`

---

## Partie F — Rôles, launchpad et tuiles standard

### F1. Ce que voit l'acheteur

| Tuile | Origine | À faire |
|---|---|---|
| **Sources à déterminer** | Z — `ResaSource-determine` | Catalogue `ZRESA_SRC_TC`, groupe `ZRESA_SRC_TG`, target mapping de l'application BSP `ZRESA_SRC_APP` |
| Demandes d'achat | **SAP standard** | Activer l'application standard et ajouter son catalogue SAP au rôle (relevé R7) |
| Commandes d'achat | **SAP standard** | Idem |
| Convertir les DA en commandes (ME59N) | Transaction | Target mapping de type *Transaction* dans `ZRESA_SRC_TC`, alias système, autorisation de transaction |
| Suivi des réservations, Monitoring des IDocs | Z, inchangées | Catalogue existant du cockpit |

> **⚠️ R7** — ne pas inventer les identifiants des applications standard : les relever dans la
> *Fiori Apps Reference Library* pour S/4HANA 2021 et vérifier leur objet sémantique. Les intentions
> utilisées dans le launchpad local (`PurchaseRequisition-manage`, `PurchaseOrder-manage`) sont des
> **hypothèses**, signalées comme telles dans
> [../apps/srcappro/webapp/test/navPlaceholder/targets.json](../apps/srcappro/webapp/test/navPlaceholder/targets.json).

### F2. Rôle `ZR_RESA_SRC`

| Élément | Valeur |
|---|---|
| Catalogue et groupe | `ZRESA_SRC_TC`, `ZRESA_SRC_TG` + catalogues SAP des tuiles standard |
| `M_BANF_WRK` | `ACTVT` 02 et 03, `WERKS` selon le périmètre de l'acheteur |
| `S_SERVICE` | Service binding `ZUI_RESASRC_O4` |
| Transaction | `ME59N` si la tuile de conversion est proposée |

Aucun objet d'autorisation Z : la v1 en créait un pour la petite caisse, hors périmètre désormais.

---

## Partie G — Recette, transport et exploitation

### G1. Liste de recette

Écran :

- ☐ La liste ne contient que des postes de DA sans source, non convertis, non supprimés, non clôturés.
- ☐ Les postes les plus anciens apparaissent en premier.
- ☐ Les filtres division, article, réservation, statut et origine fonctionnent.
- ☐ Le bouton « Retenir une source » est actif sur une ligne sélectionnée, inactif sur un poste sans article.
- ☐ Le champ « Source retenue » de la boîte de dialogue ouvre la pop-up (relevé R5).
- ☐ La pop-up ne montre que les sources du poste sélectionné.
- ☐ Les colonnes de la pop-up sont renseignées : type, désignation, disponibilité en couleur, quantité, prix, délai, rang.
- ☐ Le filtre « Type de source » de la pop-up fonctionne.
- ☐ Aucune source n'est présélectionnée.
- ☐ Un poste sans aucune source affiche une pop-up vide, et non un message d'erreur.

Fonctionnement :

- ☐ Valider sans choisir une source affiche le message 005 et n'écrit rien.
- ☐ Retenir une source fournisseur : `ZTRESA_SRCSEL` alimentée (statut `SEL`) **et** `EBAN` mise à jour (fournisseur fixe, fiche info, organisation d'achat).
- ☐ Après succès, le poste **quitte** la liste de travail.
- ☐ Le poste sorti de la liste est convertible par ME59N / la tuile standard de commande d'achat.
- ☐ Retenir une source que le standard refuse : message affiché à l'écran, **aucune écriture**, poste inchangé.
- ☐ Si le refus survient en sauvegarde : statut `ERR`, message du standard visible dans la liste et sur la page objet, poste toujours présent.
- ☐ Retenir une nouvelle source sur un poste en `ERR` remplace le choix précédent.
- ☐ Une source disparue entre l'ouverture de la pop-up et la validation donne le message 001.
- ☐ Le programme de détermination indisponible donne le message 002, et non une liste vide.
- ☐ Deux utilisateurs sur le même poste : le second reçoit le message 003.
- ☐ Un utilisateur sans activité 02 sur la division ne peut pas exécuter l'action.
- ☐ Un utilisateur sans activité 03 sur la division ne voit pas les postes de cette division.

Non-régression :

- ☐ `zlr.resatracking` et `zlr.resaidoc` fonctionnent ; leur bouton de barre d'outils ouvre la nouvelle application.
- ☐ Les tuiles standard de DA et de commande d'achat s'ouvrent depuis le launchpad.

Relecture de code :

- ☐ Aucun `COMMIT WORK`, `ROLLBACK WORK` ou `BAPI_TRANSACTION_COMMIT` dans le code livré.
- ☐ Aucune opération `create` / `update` / `delete` exposée dans les définitions de comportement.
- ☐ Aucun `⟨…⟩` restant dans les objets activés.

### G2. Impact sur les objets existants

| Objet | Action |
|---|---|
| `ZC_ResaChainTracking.asddlxs`, `ZC_ResaIdocTracking.asddlxs` | Bouton de barre d'outils repointé de `ResaCockpit-display` vers `ResaSource-determine` |
| `ZI_ResaChainCube` | Contient encore la jointure sur `ztresa_pcorder` (petite caisse, v1) et le type de document `ZDI5` en dur. **À reprendre** : retirer la jointure, lire le type de document réel de la commande. Sans cela la vue ne s'active pas, `ztresa_pcorder` n'existant pas |
| `ZC_ResaChainQuery`, `ZC_ResaIdocQuery` (+ extensions) | Supprimées : elles ne servaient que les cartes de l'Overview Page |
| `ZI_ResaSrcEdi`, `ZI_ResaSrcWhse`, `ZI_ResaSrcStore`, `ZI_ResaSrcCash`, `ZI_ResaSourceAvail`, `ZC_ResaPurReqWorklist`, `ZC_ResaSourceOption`, `ZC_ResaPettyCashOrder` (+ extensions) | Supprimées : remplacées par l'entité personnalisée |
| Services OData V2 `ZCRESASRC_CDS`, `ZCRESAKPI_CDS`, `ZCRESAIDKPI_CDS` | À dé-enregistrer dans `/IWFND/MAINT_SERVICE` |
| Applications BSP `ZOVP_RESACOCKPIT` et celles des quatre maquettes | À dé-déployer si elles ont été déployées |

> **⚠️ `ZI_ResaChainCube` est le seul objet existant qui ne s'active plus en l'état.** C'est une
> conséquence directe de l'abandon de la petite caisse : le cube référence une table qui n'est plus
> créée. À traiter avant de transporter, sinon le suivi de la chaîne tombe.

### G3. Transport

Un seul ordre workbench suffit : package `ZRESA_SRC`, pas d'objet de customizing. Ordre d'import
sans objet puisqu'il n'y a qu'un ordre ; à l'intérieur, l'ordre d'activation de
[../abap/README.md](../abap/README.md) s'applique en cas de réactivation manuelle.

### G4. Exploitation

- L'application n'a **aucun job**, **aucune table de customizing** et **aucune donnée à reprendre**.
- `ZTRESA_SRCSEL` croît d'une ligne par poste traité : volumétrie de l'ordre du nombre de postes de
  DA sans source, sans purge nécessaire à court terme.
- Le point de surveillance est `⟨PROGRAMME_SOURCES⟩` : s'il devient indisponible, l'application
  affiche le message 002 et aucune source ne peut être retenue. Prévoir la supervision côté
  programme, pas côté application.

---

## Annexe A — Diagnostic des incidents fréquents

| Symptôme | Cause probable | Action |
|---|---|---|
| La pop-up s'ouvre vide alors que le poste a des sources | Paramètres de contexte non alimentés (relevé R5) : la classe de requête reçoit un filtre vide et lève le message 004 | Contrôler la requête envoyée au service ; appliquer le repli §2.3 |
| La pop-up affiche toutes les sources de tous les postes | `additionalBinding` absent ou mal orthographié dans `ZD_ResaSourceSelParam` | Comparer les noms d'éléments avec `ZI_ResaSourceOption` |
| Message 004 systématique | Filtre du poste non transmis, ou noms d'éléments en filtre différents de `PURCHASEREQUISITION` / `PURCHASEREQUISITIONITEM` | Tracer `get_as_ranges( )` dans `ZCL_RESA_SRC_QUERY` |
| Le bouton « Retenir une source » n'apparaît pas | Annotation `#FOR_ACTION` absente de l'extension de métadonnées, ou `use action` manquant dans la projection | Partie E1 |
| L'action réussit mais la liste ne change pas | `Common.SideEffects` non généré | Vérifier `result [1] $self` dans la définition de comportement |
| Le poste reste dans la liste avec un statut `SEL` | L'affectation a réussi dans `ZTRESA_SRCSEL` mais pas dans la DA | Contrôler les champs renseignés par `ZCL_RESA_SRC_PRUPDATE` (R4) : un BAPI qui ne renvoie pas d'erreur mais n'écrit rien |
| Tous les postes disparaissent de la liste | Le `where` de `ZI_ResaPurReqNoSource` porte sur de mauvais éléments (R1) | Comparer avec `EBAN` sur un poste connu |
| `cx_rap_query_provider` refusée à l'activation avec `MESSAGE` | Addition non supportée dans le système (R6) | Utiliser `EXPORTING textid = ...` et vérifier l'affichage |
| Erreur de verrou permanente | Objet de verrouillage ou paramètres inexacts (R3) | SE11, puis corriger `lock` et `cleanup_finalize` |

---

## Annexe B — Ce que la v2 abandonne par rapport à la v1

| Objet de la v1 | Sort en v2 | Raison |
|---|---|---|
| `ZTRESA_SRCDOCTY`, `ZTRESA_REPLCFG`, `ZTRESA_PCLIMIT`, `ZTRESA_NEIGHB`, `ZTRESA_WHSE` | Abandonnées | Les sources viennent du programme S/4 : aucune règle à paramétrer ici |
| `ZTRESA_PCORDER`, `ZTRESA_REPLREQ` | Abandonnées | Petite caisse et réapprovisionnement hors périmètre |
| Tranche de numéros `ZRESA_PC`, objet d'autorisation `ZRESA_PC` | Abandonnés | Idem |
| `ZI_ResaSrcEdi`, `ZI_ResaSrcWhse`, `ZI_ResaSrcStore`, `ZI_ResaSrcCash`, `ZI_ResaSrcCandidate`, `ZI_ResaSourceAvail`, `ZI_ResaSourceCount` | Remplacées par `ZI_ResaSourceOption` | Une entité personnalisée à la place de sept vues |
| BO `ZR_ResaPettyCash`, `ZR_ResaReplenRequest` | Abandonnés | Hors périmètre |
| Actions `ConvertToPurchaseOrder`, `CreatePettyCashOrder`, `CreatePurchaseRequisition`, `CreateReplenishmentOrder` | Abandonnées | Conversion et création par les tuiles standard |
| Action `AssignSource` | Devient `SelectSource`, et **écrit dans la DA** | C'était le seul besoin réel |
| 4 projections, 4 services, 4 applications | 1 de chaque | Une seule tuile spécifique |
| Alternatives 1 et 2 | Sans objet | L'arbitrage est tranché |

Ce qui est **conservé** de la v1 : le choix « managed with unmanaged save », l'absence de draft, le
verrou pessimiste sur la DA, l'interdiction de tout `COMMIT` hors sauvegarde, l'absence de
proposition automatique de source, la table `ZTRESA_SRCSEL` (réduite), et la convention de
documentation.

Les deux documents de la v1 restent disponibles dans [archive/](archive/) : ils contiennent le
contexte métier, les avis exprimés et les questions ouvertes, qui n'ont pas été rejoués ici.

---

## Annexe C — Paramètres à renseigner

| Paramètre | Signification | Où | Relevé |
|---|---|---|---|
| `⟨PROGRAMME_SOURCES⟩` | Nom du module fonction (ou de la classe) de détermination des sources | `ZCL_RESA_SRC_PROVIDER` | R2 |
| `⟨STRUCTURE_SOURCES⟩` | Structure de la table de sortie de ce programme | `ZCL_RESA_SRC_PROVIDER` | R2 |
| `⟨OBJET_VERROU_EBAN⟩` | Objet de verrouillage de `EBAN` | `ZBP_R_RESAPURREQSOURCE` (`lock`, `cleanup_finalize`) | R3 |
| `<hote-s4hana>`, `<port>`, mandant | Accès au système | `apps/srcappro/ui5.yaml`, `ui5-deploy.yaml` | — |
| `<ordre-de-transport>` | Ordre de transport du déploiement BSP | `apps/srcappro/ui5-deploy.yaml` | — |
| Intentions des tuiles standard | Objets sémantiques et actions réels | launchpad, `targets.json` | R7 |

---

## Annexe D — Index des copies d'écran

| N° | Sujet | Partie |
|---|---|---|
| 01 | `I_PurchaseRequisitionItem` dans ADT, éléments relevés | §2.3 |
| 02 | Signature de `⟨PROGRAMME_SOURCES⟩` | §2.3 |
| 03 | Objet de verrouillage de `EBAN` | §2.3 |
| 04 | Service binding publié et aperçu | E2 |
| 05 | Liste des postes sans source | E3 |
| 06 | Pop-up des sources disponibles | E3 |
| 07 | Poste refusé par le standard | E3 |

---

## Annexe E — Historique des versions

| Version | Date | Évolution |
|---|---|---|
| v1.0 | — | Socle complet : 4 applications, 8 tables, sources calculées en CDS, petite caisse, réapprovisionnement. [Archivée](archive/Spec-SourceAppro-RAP-v1.md) |
| v2.0 | — | Recentrage : tuiles Fiori standard pour la DA et la commande d'achat, une seule application spécifique, sources rendues par un programme S/4, choix écrit dans la demande d'achat |
