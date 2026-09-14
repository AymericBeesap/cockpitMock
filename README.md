# Cockpit de suivi des réservations magasin

Implémentation du mode opératoire [.claude/Spec.md](.claude/Spec.md) (MO-OVP-RESACOCKPIT-2021FPS02-v1.0) :
une **Overview Page** (indicateurs) et un **List Report** (suivi ligne à ligne) SAP Fiori elements OData V2,
sur un modèle 100 % ABAP CDS — SAP S/4HANA 2021 FPS02, SAPUI5 1.96.

## Contenu

| Dossier | Contenu | Partie du MO |
|---|---|---|
| [cds/](cds/) | Vues CDS (`.asddls`) et extensions de métadonnées (`.asddlxs`) à recopier dans Eclipse ADT | A |
| [apps/resacockpit/](apps/resacockpit/) | Overview Page `zovp.resacockpit`, intention `ResaCockpit-display` | B |
| [apps/resatracking/](apps/resatracking/) | List Report + page objet `zlr.resatracking`, intention `ResaChain-track` | C |

Chaque application contient :

- `ui5.yaml` — exécution contre le système S/4HANA (proxy `/sap`, **URL et mandant à renseigner**) ;
- `ui5-mock.yaml` — exécution locale sur le mock server (`webapp/localService`) ;
- `ui5-deploy.yaml` — déploiement BSP (**package et ordre de transport à renseigner**) ;
- `webapp/localService/<service>/` — `metadata.xml`, `annotations.xml` (copie de l'annotation service `_VAN`) et données de test.

## Démarrage local

Prérequis : Node.js 20.11 ou supérieur.

```sh
npm install
npm run start:launchpad  # launchpad local : accueil avec les tuiles
npm run start:cockpit    # même launchpad, ouvert sur le cockpit
npm run start:tracking   # même launchpad, ouvert sur le suivi détaillé
npm run start:idoc       # même launchpad, ouvert sur le monitoring des IDocs
npm run build            # build des trois applications
```

Toutes ces commandes démarrent **le même serveur** (configuration `apps/resacockpit/ui5-mock.yaml`, port 8080) qui sert
les trois applications, les quatre services mockés et la page de substitution : les liens fonctionnent quelle que soit
la commande utilisée. N'en lancer qu'une à la fois. `npm run start-standalone` dans `apps/resatracking` ou `apps/resaidoc`
ouvre l'application seule, sans navigation vers les autres applications.

> **⚠️ Redémarrer après chaque modification** de `ui5-mock.yaml`, des métadonnées, des annotations ou des données mockées :
> le serveur les charge au démarrage. Arrêter le serveur (Ctrl+C) puis relancer la commande.

| Symptôme en local | Cause | Action |
|---|---|---|
| Aucun lien ne fonctionne, `failed to load .../Component.js` en console | Serveur démarré avant l'ajout de la navigation, ou application lancée seule (`start-standalone`) | Arrêter le serveur et relancer `npm run start:launchpad` |
| Cartes vides ou page du cockpit qui ne finit pas de charger | Serveur démarré avec une ancienne configuration pointant vers des fichiers supprimés | Idem : arrêter et relancer |
| Port 8080 déjà utilisé | Un autre serveur du projet tourne encore | Arrêter l'autre serveur avant de relancer |

Pour travailler contre le système : renseigner `backend.url` / `client` dans `ui5.yaml`, puis `npm start` dans le dossier de l'application.

Les données de test : 36 postes de DA (13 en attente, taux de conversion des réservations 70,8 %), 30 IDocs dont 8 en erreur.
Le mock server ne sait pas agréger une requête analytique V2 : le hook
[analyticalAggregation.js](apps/resacockpit/webapp/localService/analyticalAggregation.js) regroupe les lignes selon les
dimensions de `$select`, recalcule les formules (taux de conversion, taux d'intégration) et applique `$skip` / `$top`
après agrégation (en-têtes KPI en `$top=1`). `MOCK_AGG_DEBUG=1` trace les propriétés reçues par le hook.

Valeurs attendues en local : 13 postes en attente (vert), taux de conversion 71 % (critique), 8 IDocs en erreur (critique).

## Ordre d'activation des vues CDS

1. `ZI_ResaIdocLastStatus` — 2. `ZI_ResaIdocMonitor` — 3. `ZI_ResaChainCube` — 4. `ZC_ResaChainQuery` —
5. `ZC_ResaIdocQuery` — 6. `ZC_ResaChainTracking` — 7. `ZC_ResaIdocTracking` — 8. les quatre extensions de métadonnées.

Puis enregistrer dans `/IWFND/MAINT_SERVICE` : `ZCRESAKPI_CDS`, `ZCRESAIDKPI_CDS`, `ZCRESATRACK_CDS` (et `ZCRESAIDTRACK_CDS` si le monitoring IDoc est publié).

> **⚠️ À vérifier avant activation (§A3)** — les noms réels dans `I_PurchaseRequisitionItem` :
> `ZZReservation`, `SalesOrder` / `SalesOrderItem`, `PurchaseOrder` / `PurchaseOrderItem`, `PurchaseRequisitionPrice`.
> Vérifier aussi le regroupement des statuts IDoc (§2.3) dans `ZI_ResaIdocMonitor`.

## Écarts et compléments par rapport au MO

| # | Constat dans le MO | Traitement |
|---|---|---|
| 1 | La carte `card03_idoc` référence `Chart#ErreursParMagasin` et `DataPoint#IDocsEnErreur`, non définis | Extension `ZC_ResaIdocQuery.asddlxs` créée (seuils 5 / 15, plus `TauxIntegration`) |
| 2 | La carte `card02_conversion` est analytique sans graphique | Ajout de `Chart#RepartitionParEtape` (anneau par étape) |
| 3 | `ZC_ResaIdocTracking` est annotée (§A7.3) mais jamais définie | Vue créée sur `ZI_ResaIdocMonitor` ; pas d'application Fiori dédiée (tuile optionnelle, §E2) |
| 4 | La carte `card04_liste` doit montrer les postes « les plus anciens en attente » sans filtre ni tri | `SelectionVariant#EnAttente` (`ChainStage = PR`) et `PresentationVariant#Anciens` (date croissante) |
| 5 | La carte de liste doit ouvrir la page objet du suivi (§D1) | `Identification#Carte` vers `ResaChain-track`, clés du poste passées en paramètres |
| 6 | §A7.2 et §D2 annotent `ZC_ResaChainTracking` dans deux extensions de la même couche | Fusionnées en une seule (une seule MDE par couche) |
| 7 | `@UI.selectionVariant.parameters` est réservé aux paramètres CDS | Remplacé par `filter: 'OriginType EQ "RESA"'` |
| 8 | Origine et étape affichées sous forme de codes (`RESA`, `PR`…) | Libellés `OriginTypeText` / `ChainStageText` calculés dans le cube, `@ObjectModel.text.element` |
| 9 | Les cartes analytiques exigent `UI.Identification` pour la navigation au clic | Intentions `ResaChain-track` (requête chaîne) et `ResaIdoc-monitor` (requête IDoc) |
| 10 | Le List Report V2 attend « Exécuter » avant de charger | `dataLoadSettings.loadDataOnAppLaunch: always` |

## Navigation

`npm run start:launchpad` ouvre un launchpad local contenant les trois applications du projet : toutes les navigations
entre elles fonctionnent. Les cibles hors projet ouvrent une **page « Navigation à configurer »** qui rappelle quoi créer
([navPlaceholder/targets.json](apps/resacockpit/webapp/test/navPlaceholder/targets.json)). Les emplacements concernés
sont marqués `TODO NAVIGATION` dans les CDS et dans [flpSandbox.html](apps/resacockpit/webapp/test/flpSandbox.html).

| # | Depuis | Vers (intention) | Mécanisme | Statut |
|---|---|---|---|---|
| 1 | Cockpit — carte « Accès rapides » | `ResaChain-track` | lien statique `card05_liens` | 🟢 opérationnelle |
| 2 | Cockpit — carte « Accès rapides » | `ResaIdoc-monitor` | lien statique `card05_liens` | 🟢 opérationnelle |
| 3 | Cockpit — carte « Accès rapides » | `PurchaseRequisition-convertAuto` (ME59N) | lien statique `card05_liens` | 🟠 **à configurer** |
| 4 | Cockpit — carte « Postes les plus anciens » | `ResaChain-track` + clés du poste | `UI.Identification#Carte` | 🟢 opérationnelle |
| 5 | Cockpit — graphiques postes en attente / conversion | `ResaChain-track` + dimensions cliquées | `UI.Identification` de `ZC_ResaChainQuery` | 🟢 opérationnelle |
| 6 | Cockpit — graphique intégration | `ResaIdoc-monitor` + magasin | `UI.Identification` de `ZC_ResaIdocQuery` | 🟢 opérationnelle |
| 7 | Suivi — pied de page de la page objet | `PurchaseRequisition-displayFactSheet` | `UI.Identification`, `Determining` | 🟠 **à configurer** |
| 8 | Suivi — pied de page de la page objet | `PurchaseOrder-displayFactSheet` | `UI.Identification`, `Determining` | 🟠 **à configurer** |
| 9 | Suivi / monitoring — barre d'outils | `ResaCockpit-display` | `UI.LineItem` `DataFieldForIntentBasedNavigation` | 🟢 opérationnelle |

### À configurer dans le Launchpad réel

| Intention | À créer | Référence MO |
|---|---|---|
| `PurchaseRequisition-displayFactSheet` | Relever l'objet sémantique / action réels de la fiche SAP (catalogues achats) ; corriger le CDS s'ils diffèrent ; ajouter le catalogue SAP au rôle | §D2, §E3 |
| `PurchaseOrder-displayFactSheet` | Idem pour la fiche de commande d'achat | §D2, §E3 |
| `PurchaseRequisition-convertAuto` | Target mapping de type **Transaction** `ME59N` dans le catalogue Z, alias système, autorisation de transaction | §D3, §E3 |
| `ResaCockpit-display`, `ResaChain-track`, `ResaIdoc-monitor` | Tuiles et target mappings des trois applications déployées, dans le catalogue Z (les inbounds sont dans les manifestes) | §E2 |

La page de substitution n'existe que dans le launchpad local (`webapp/test/`, exclu du build et du déploiement).

> **Pas de navigation IDoc → suivi détaillé** : les deux modèles restent volontairement disjoints (§1.3), le monitoring IDoc
> ne porte pas le numéro de réservation.

> **⚠️ Sensibilité des données IDoc (§E3)** : l'application `zlr.resaidoc` restitue des messages d'erreur techniques ;
> restreindre sa tuile et son catalogue aux profils qui en ont l'usage.

## Limites connues en local

- Le filtre global de l'Overview Page n'agit que sur les cartes du modèle `mainModel` (comportement attendu, §B3).
- Chaque application garde aussi son sandbox autonome (`npm run start:tracking`, `npm run start:idoc`) sans navigation sortante.
