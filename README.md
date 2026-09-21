# Détermination de la source d'approvisionnement — et suivi des réservations magasin

Le cockpit s'appuie sur les **tuiles Fiori standard** de demande d'achat et de commande d'achat.
Une seule application est spécifique : la **liste des postes de DA sans source d'approvisionnement**,
avec une **pop-up de choix** parmi les sources disponibles, rendues par un programme de S/4.

Réalisation en **RAP** — OData V4, Fiori elements V4, sans draft — SAP S/4HANA 2021 FPS02, SAPUI5 1.96.
Mode opératoire : **[.claude/Spec-SourceAppro-RAP.md](.claude/Spec-SourceAppro-RAP.md)**
(MO-SRCAPPRO-RAP-2021FPS02-v2.0).

## Contenu

| Dossier | Contenu | Référence |
|---|---|---|
| [abap/](abap/) | Objets RAP de la détermination de la source : table, vues CDS, entité personnalisée, business object, classes, service | [MO RAP](.claude/Spec-SourceAppro-RAP.md) parties A à E |
| [apps/srcappro/](apps/srcappro/) | Application `zlr.srcappro`, intention `ResaSource-determine` — la seule tuile spécifique | idem, partie E3 |
| [cds/](cds/) | Vues CDS OData V2 du suivi de la chaîne et du monitoring IDoc | [MO Cockpit](.claude/Spec.md) |
| [apps/resatracking/](apps/resatracking/) | Suivi de la chaîne `zlr.resatracking`, intention `ResaChain-track` | idem, partie C |
| [apps/resaidoc/](apps/resaidoc/) | Monitoring des IDocs `zlr.resaidoc`, intention `ResaIdoc-monitor` | idem, §A7.3 |
| [tools/generate-mockdata.js](tools/generate-mockdata.js) | Données de démonstration cohérentes des trois services mockés | — |

Les documents de l'étape précédente — arbitrage entre deux alternatives, puis socle RAP complet à
quatre applications — sont conservés dans [.claude/archive/](.claude/archive/). Ils gardent le
contexte métier, les avis exprimés et les questions ouvertes.

## Comment la pop-up fonctionne

```
liste des postes sans source
        │  bouton « Retenir une source »
boîte de dialogue de l'action SelectSource
        │  champ « Source retenue »
pop-up : aide à la saisie sur l'entité personnalisée ZI_ResaSourceOption
        │  ZCL_RESA_SRC_QUERY → ZCL_RESA_SRC_PROVIDER → ⟨PROGRAMME_SOURCES⟩ dans S/4
choix retenu → trace dans ZTRESA_SRCSEL + écriture de la source dans la DA (BAPI_PR_CHANGE)
        │
le poste quitte la liste → conversion par les tuiles standard (ME59N, Manage Purchase Orders)
```

Rien n'est écrit en JavaScript : la pop-up est produite par l'annotation
`@Consumption.valueHelpDefinition` de `ZD_ResaSourceSelParam`, et ses colonnes par les
`@UI.lineItem` de `ZI_ResaSourceOption`. Aucune source n'est présélectionnée : le comparatif est
restitué, le choix est manuel.

## Démarrage local

Prérequis : Node.js 20.11 ou supérieur.

```sh
npm install
npm run start:launchpad  # launchpad local : accueil avec les tuiles
npm run start:src        # même launchpad, ouvert sur la détermination de la source
npm run start:tracking   # même launchpad, ouvert sur le suivi de la chaîne
npm run start:idoc       # même launchpad, ouvert sur le monitoring des IDocs
npm run mockdata         # régénère les données de démonstration
npm run build            # build des trois applications
```

Toutes ces commandes démarrent **le même serveur** (configuration `apps/srcappro/ui5-mock.yaml`,
port 8080) qui sert les trois applications, le service V4 et les deux services V2 mockés, ainsi que
la page de substitution de navigation. N'en lancer qu'une à la fois.

> **⚠️ Redémarrer après chaque modification** de `ui5-mock.yaml`, des métadonnées, des annotations
> ou des données mockées : le serveur les charge au démarrage.

| Symptôme en local | Cause | Action |
|---|---|---|
| `EADDRINUSE: Port 8080 is already in use` | Un autre serveur du projet tourne encore | Arrêter l'autre serveur, ou lancer avec `--port 8081` |
| Aucun lien ne fonctionne, `failed to load .../Component.js` | Serveur démarré avant l'ajout d'une application | Arrêter et relancer `npm run start:launchpad` |
| La pop-up des sources s'ouvre vide | Le poste de DA n'est pas transmis en filtre | C'est le relevé R5 du MO : voir les replis au §2.3 |
| Les actions ne reflètent plus les données d'origine | Le mock server modifie son état **en mémoire** | Redémarrer : les fichiers de données sont rechargés tels quels |

Pour travailler contre le système : renseigner `backend.url` / `client` dans
`apps/srcappro/ui5.yaml`, puis `npm start` dans le dossier de l'application.

## Données de démonstration

36 postes de DA dont **13 sans source** (taux de conversion des réservations 70,8 %), 30 IDocs dont
8 en erreur, 30 sources réparties sur les postes ouverts.

Cas de figure volontairement présents, pour éprouver l'écran sans S/4 :

| Cas | Où | Attendu |
|---|---|---|
| Source fournisseur retenue | poste `0010010002` / `00010` | Statut « Source retenue », source écrite dans la DA |
| Source centre voisin ou entrepôt retenue | n'importe quel poste en proposant une | **Refus du standard** : statut rouge et message — c'est le point dur du relevé R4 |
| Poste déjà refusé | 2 postes en statut `ERR` | Message du standard visible, poste toujours dans la liste |
| Poste sans aucune source | 2 postes | Pop-up vide, et non un message d'erreur |
| Validation sans choisir de source | tous | Message « Retenir une source d'approvisionnement » |

> **Écart local assumé** : en réel, un poste dont l'affectation réussit **quitte** la liste, puisque
> la demande d'achat porte désormais une source. Le mock server conserve la ligne pour que Fiori
> elements puisse rafraîchir l'instance renvoyée par l'action ; le poste reste donc visible avec le
> statut « Source retenue ».

## Ordre d'activation des objets ABAP

Détermination de la source : voir [abap/README.md](abap/README.md) — 12 étapes, des éléments de
données au service binding.

Suivi de la chaîne et monitoring IDoc (inchangés, OData V2) :
`ZI_ResaIdocLastStatus` → `ZI_ResaIdocMonitor` → `ZI_ResaChainCube` → `ZC_ResaChainTracking` →
`ZC_ResaIdocTracking` → les deux extensions de métadonnées. Puis enregistrer `ZCRESATRACK_CDS` et
`ZCRESAIDTRACK_CDS` dans `/IWFND/MAINT_SERVICE`.

> **⚠️ Services V2 à dé-enregistrer** : `ZCRESASRC_CDS`, `ZCRESAKPI_CDS` et `ZCRESAIDKPI_CDS`
> correspondent à l'Overview Page et aux quatre maquettes, abandonnées.

> **⚠️ `ZI_ResaChainCube` a été reprise** : la jointure sur la table des commandes petite caisse a
> été retirée et le type de document aval est désormais lu sur l'en-tête de la commande d'achat, au
> lieu d'être écrit `ZDI5` en dur. Vérifier `PurchasingDocumentType` sur `I_PurchaseOrder` avant
> activation.

## Navigation

| # | Depuis | Vers (intention) | Mécanisme | Statut |
|---|---|---|---|---|
| 1 | Launchpad | `ResaSource-determine` | Tuile du catalogue `ZRESA_SRC_TC` | 🟢 opérationnelle |
| 2 | Launchpad | Demandes d'achat (standard) | Catalogue SAP | 🟠 **à activer** |
| 3 | Launchpad | Commandes d'achat (standard) | Catalogue SAP | 🟠 **à activer** |
| 4 | Launchpad | `PurchaseRequisition-convertAuto` (ME59N) | Target mapping de type Transaction | 🟠 **à configurer** |
| 5 | Suivi / monitoring — barre d'outils | `ResaSource-determine` | `UI.LineItem` `DataFieldForIntentBasedNavigation` | 🟢 opérationnelle |
| 6 | Suivi — pied de page de la page objet | `PurchaseRequisition-displayFactSheet` | `UI.Identification`, `Determining` | 🟠 **à configurer** |
| 7 | Suivi — pied de page de la page objet | `PurchaseOrder-displayFactSheet` | `UI.Identification`, `Determining` | 🟠 **à configurer** |

Les cibles hors projet ouvrent en local une **page « Navigation à configurer »** qui rappelle quoi
créer ([navPlaceholder/targets.json](apps/srcappro/webapp/test/navPlaceholder/targets.json)).

> **⚠️ Les intentions des tuiles standard sont des hypothèses** (`PurchaseRequisition-manage`,
> `PurchaseOrder-manage`) : relever les objets sémantiques et actions réels dans la *Fiori Apps
> Reference Library* pour S/4HANA 2021 — c'est le relevé R7 du mode opératoire.

## Limites connues

- Les paramètres de contexte de l'action doivent être pré-alimentés par Fiori elements pour que la
  pop-up soit filtrée sur le poste : comportement à confirmer sous SAPUI5 1.96 (relevé R5), avec
  deux replis documentés.
- Chaque application conserve son sandbox autonome (`npm start` dans son dossier), sans navigation
  sortante.
