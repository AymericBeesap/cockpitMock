# Mode opératoire — Cockpit de suivi des réservations magasin

## Réservation · Demande d'achat · Commande d'achat

**Overview Page + List Report — SAP Fiori elements**
**SAP S/4HANA (Private Cloud and On-Premise) 2021 — FPS02**

| Attribut | Valeur |
|---|---|
| Référence du document | MO-OVP-RESACOCKPIT-2021FPS02-v1.0 |
| Documents liés | [MO Extension](MO%20Extension.md) · [MO Annotations CDS](MO%20Annotations%20CDS.md) · [MO Cockpit OVP](MO%20Cockpit%20OVP.md) |
| Objets créés | Cockpit Overview Page + List Report de suivi détaillé |
| Flux suivis | Réservations magasin par IDoc · Commande client individuelle vers DA et commande d'achat |
| Type de message IDoc | `Z_CREA_PR`, sens entrant |
| Architecture | 100 % ABAP — CDS analytique, OData V2, Gateway embedded |
| Version produit | SAP S/4HANA 2021 FPS02 |
| Outils | Eclipse + ABAP Development Tools · VS Code + SAP Fiori tools · SAP GUI |
| Auteur | … |
| Vérifié par | … |
| Date de rédaction | … |
| Statut | Version de travail |

> **Convention de ce document**
> Chaque emplacement de copie d'écran est signalé par un bloc `📸 COPIE D'ÉCRAN N°XX`.
> Déposez vos images dans `images/RESA-COCKPIT/` puis remplacez la ligne indiquée par le lien Markdown correspondant.

---

## Sommaire

- [1. Objet et flux métier](#1-objet-et-flux-métier)
- [2. Prérequis](#2-prérequis)
- [3. Synoptique de la démarche](#3-synoptique-de-la-démarche)
- [Partie A — Modèle de données](#partie-a--modèle-de-données)
- [Partie B — Overview Page](#partie-b--overview-page)
- [Partie C — List Report de suivi détaillé](#partie-c--list-report-de-suivi-détaillé)
- [Partie D — Navigation](#partie-d--navigation)
- [Partie E — Déploiement et publication](#partie-e--déploiement-et-publication)
- [Partie F — Recette, transport et exploitation](#partie-f--recette-transport-et-exploitation)
- [Annexe A — Diagnostic des incidents fréquents](#annexe-a--diagnostic-des-incidents-fréquents)
- [Annexe B — Index des copies d'écran](#annexe-b--index-des-copies-décran)
- [Annexe C — Historique des versions](#annexe-c--historique-des-versions)

---

## 1. Objet et flux métier

### 1.1 Objet

Ce mode opératoire décrit la construction d'un cockpit de pilotage couvrant l'entrée des réservations transmises par les magasins et leur transformation jusqu'à la commande d'achat. Il produit deux applications complémentaires : une **Overview Page** pour les indicateurs, et un **List Report** pour l'analyse ligne à ligne.

### 1.2 Les deux flux suivis

| Flux | Parcours | Point de suivi |
|---|---|---|
| Entrée | Magasin → IDoc `Z_CREA_PR` → demande d'achat | Intégration réussie ou en erreur |
| Transformation | Commande client → demande d'achat → commande d'achat | Étape atteinte et reste à convertir |

Les deux flux convergent sur la demande d'achat, qui devient le **pivot du modèle** : elle porte le numéro de réservation d'origine pour le premier flux, la référence de commande client pour le second, et la référence de commande d'achat en aval.

### 1.3 Une limite structurelle à connaître

Le rattachement entre un IDoc et la demande d'achat repose sur le numéro de réservation stocké dans la demande. Ce mécanisme ne fonctionne que si la demande a été créée : **un IDoc en erreur n'a produit aucune demande**, et reste donc invisible depuis le modèle de la chaîne.

| Situation | Où l'IDoc est visible |
|---|---|
| IDoc traité, demande créée | Modèle de la chaîne, par le numéro de réservation |
| IDoc en erreur, aucune demande | Modèle de monitoring des IDocs uniquement |
| IDoc en attente de traitement | Modèle de monitoring des IDocs uniquement |

> **⚠️ Conséquence de conception**
> Le cockpit s'appuie sur **deux modèles distincts, volontairement non joints**. Le monitoring des IDocs répond à la question « qu'est-ce qui n'est pas entré », le modèle de la chaîne à la question « qu'est-ce qui n'est pas encore converti ». Vouloir les fusionner en une seule vue conduit à une jointure qui perd précisément les cas les plus intéressants.

### 1.4 Contenu du cockpit

| Élément | Application | Contenu |
|---|---|---|
| Postes en attente | Overview Page | Volume non converti, par division |
| Taux de conversion | Overview Page | Rapport converti sur total, avec seuils |
| Intégration des réservations | Overview Page | IDocs en erreur par magasin |
| Postes les plus anciens | Overview Page | Liste des dossiers à traiter en priorité |
| Accès rapides | Overview Page | Suivi détaillé, monitoring IDoc, ME59N |
| Suivi de la chaîne | List Report | Une ligne par poste, de la réservation à la commande |
| Détail d'un poste | Page objet | Origine, demande, commande, navigation |

### 1.5 Hors périmètre

- Création ou modification du type de message IDoc et de son module d'entrée.
- Ajout du champ de réservation à la demande d'achat : il est supposé déjà en place.
- Retraitement des IDocs en erreur, qui relève des transactions standard.
- Paramétrage ALE et des partenaires.
- Analyse des causes fonctionnelles des erreurs d'intégration.

---

## 2. Prérequis

### 2.1 Prérequis fonctionnels

| Élément | Exigence |
|---|---|
| Champ de réservation | Présent dans la demande d'achat et alimenté par le module d'entrée |
| Exposition du champ | Le champ doit remonter dans la vue CDS standard des postes de DA |
| Type de message | `Z_CREA_PR` actif, en sens entrant, avec partenaires paramétrés |
| Flux commande client | Commande client individuelle générant une demande d'achat |
| Données de test | IDocs traités et en erreur, postes convertis et non convertis |

> **⚠️ Vérification préalable indispensable**
> Contrôler que le champ de réservation est bien **exposé dans la vue CDS** des postes de demande d'achat, et pas seulement présent dans la table. Si l'include client a été étendu sans extension de la vue CDS, le champ est en base mais invisible du modèle. Le mode opératoire d'extension traite ce point.

> **📸 COPIE D'ÉCRAN N°01** — Eclipse ADT : aperçu de données montrant le champ de réservation dans la vue standard
> *Remplacer cette ligne par :* `![Copie 01](images/RESA-COCKPIT/capture-01.png)`

### 2.2 Prérequis techniques

| Élément | Exigence |
|---|---|
| Plateforme | SAP S/4HANA 2021 FPS02, analytique embarquée active |
| Outils | Eclipse avec ABAP Development Tools ; VS Code avec SAP Fiori tools |
| Autorisations | `S_DEVELOP`, `S_TRANSPRT`, administration Gateway et Launchpad |
| Protocole | OData V2 — vérifier qu'il répond par la route d'accès des utilisateurs |
| Package | Package de développement Z et ordres de transport |

> **📸 COPIE D'ÉCRAN N°02** — Navigateur : test d'une URL OData V2 par la route d'accès des utilisateurs
> *Remplacer cette ligne par :* `![Copie 02](images/RESA-COCKPIT/capture-02.png)`

### 2.3 Relevé des statuts IDoc

Les regroupements de statut utilisés dans le modèle doivent correspondre à ce que produit réellement votre module d'entrée. Les relever avant de coder.

| Statut | Signification usuelle | Regroupement retenu |
|---|---|---|
| 53 | Document applicatif créé | Intégré |
| 62 | IDoc transmis à l'application | Intégré |
| 51 | Document applicatif non créé | En erreur |
| 56 | IDoc erroné ajouté | En erreur |
| 61 | Traitement malgré avertissement | En erreur |
| 63 | Erreur de transmission à l'application | En erreur |
| 68 | Traitement arrêté | Abandonné |
| autres | Statuts intermédiaires | En cours |

> **📸 COPIE D'ÉCRAN N°03** — Transaction `WE02` : répartition réelle des statuts sur le type de message
> *Remplacer cette ligne par :* `![Copie 03](images/RESA-COCKPIT/capture-03.png)`

---

## 3. Synoptique de la démarche

| N° | Étape | Objet | Partie |
|---|---|---|---|
| A1 | Créer la vue du dernier statut IDoc | `ZI_ResaIdocLastStatus` | A |
| A2 | Créer la vue de monitoring IDoc | `ZI_ResaIdocMonitor` | A |
| A3 | Créer le cube de la chaîne | `ZI_ResaChainCube` | A |
| A4 | Créer la requête analytique de la chaîne | `ZC_ResaChainQuery` | A |
| A5 | Créer la requête analytique d'intégration | `ZC_ResaIdocQuery` | A |
| A6 | Créer la vue de consommation détaillée | `ZC_ResaChainTracking` | A |
| A7 | Annoter les indicateurs et le List Report | Extensions de métadonnées | A |
| A8 | Publier et tester les services | Services OData V2 | A |
| B1 | Générer l'Overview Page | Application cockpit | B |
| B2 | Configurer les cartes | Descripteur | B |
| C1 | Générer le List Report | Application de suivi | C |
| C2 | Configurer la page objet | Annotations | C |
| D | Navigation entre applications | Target mappings | D |
| E | Déploiement, tuiles et rôles | Launchpad | E |
| F | Recette, transport, exploitation | — | F |

---

## Partie A — Modèle de données

### A1 — Vue du dernier statut de chaque IDoc

Un IDoc porte plusieurs enregistrements de statut, un par étape de traitement. Le statut courant est celui dont le compteur est le plus élevé. Cette vue intermédiaire l'isole, ce qui évite les doublons dans toutes les vues suivantes.

```abap
@AbapCatalog.sqlViewName: 'ZIRESAIDMAX'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Dernier statut de chaque IDoc'

define view ZI_ResaIdocLastStatus
  as select from edids
{
  key docnum              as IDocNumber,
      max( countr )       as LastCounter
}
group by
  docnum
```

> **📸 COPIE D'ÉCRAN N°04** — Eclipse ADT : vue du dernier statut, aperçu de données
> *Remplacer cette ligne par :* `![Copie 04](images/RESA-COCKPIT/capture-04.png)`

> **ℹ️ Erreur classique**
> Joindre directement la table des statuts sans filtrer sur le dernier compteur. Chaque IDoc apparaît alors autant de fois qu'il a connu d'étapes, et tous les indicateurs sont faussés à la hausse.

---

### A2 — Vue de monitoring des IDocs

Cette vue restitue un IDoc par ligne, avec son statut courant, son libellé, le message d'erreur associé et le magasin émetteur.

```abap
@AbapCatalog.sqlViewName: 'ZIRESAIDOC'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Monitoring des IDocs de réservation magasin'

define view ZI_ResaIdocMonitor
  as select from edidc as Header

    inner join ZI_ResaIdocLastStatus as LastStatus
      on Header.docnum = LastStatus.IDocNumber

    inner join edids as Status
      on  Status.docnum = LastStatus.IDocNumber
      and Status.countr = LastStatus.LastCounter

    left outer join teds2 as StatusText
      on  StatusText.status = Header.status
      and StatusText.langua = $session.system_language
{
  key Header.docnum                          as IDocNumber,

      Header.mestyp                          as MessageType,
      Header.idoctp                          as IDocType,
      Header.sndprn                          as SenderPartner,
      Header.credat                          as CreationDate,
      Header.cretim                          as CreationTime,
      Header.status                          as IDocStatus,
      StatusText.descrp                      as IDocStatusText,

      Status.stamid                          as MessageClass,
      Status.stamno                          as MessageNumber,
      Status.statxt                          as MessageText,

      -- regroupement fonctionnel du statut
      case Header.status
        when '53' then 'OK'
        when '62' then 'OK'
        when '51' then 'KO'
        when '56' then 'KO'
        when '61' then 'KO'
        when '63' then 'KO'
        when '68' then 'AB'
        else           'EC'
      end                                    as IntegrationStatus,

      -- criticité pour l'affichage
      case Header.status
        when '53' then 3
        when '62' then 3
        when '51' then 1
        when '56' then 1
        when '61' then 1
        when '63' then 1
        when '68' then 0
        else           2
      end                                    as StatusCriticality,

      case Header.status
        when '51' then 1
        when '56' then 1
        when '61' then 1
        when '63' then 1
        else           0
      end                                    as IDocErrorCount,

      1                                      as IDocCount
}
where Header.mestyp = 'Z_CREA_PR'
  and Header.direct = '2'
```

| Élément | Rôle |
|---|---|
| `IntegrationStatus` | Regroupement fonctionnel : intégré, en erreur, abandonné, en cours |
| `StatusCriticality` | Couleur à l'affichage |
| `IDocErrorCount` | Mesure permettant de compter les erreurs par agrégation |
| `SenderPartner` | Magasin émetteur, dimension d'analyse principale |
| `MessageText` | Message d'erreur restitué à l'utilisateur |

> **📸 COPIE D'ÉCRAN N°05** — Eclipse ADT : vue de monitoring, code source
> *Remplacer cette ligne par :* `![Copie 05](images/RESA-COCKPIT/capture-05.png)`

> **📸 COPIE D'ÉCRAN N°06** — Eclipse ADT : aperçu de données, IDocs et statuts
> *Remplacer cette ligne par :* `![Copie 06](images/RESA-COCKPIT/capture-06.png)`

> **⚠️ À adapter**
> Les valeurs du regroupement doivent correspondre aux statuts réellement produits par votre module d'entrée, relevés au chapitre 2.3. Un statut non prévu tombe dans « en cours » et fausse le taux d'intégration.

---

### A3 — Cube de la chaîne

Le cube prend le poste de demande d'achat comme pivot et rattache l'amont — réservation ou commande client — et l'aval — commande d'achat.

```abap
@AbapCatalog.sqlViewName: 'ZIRESACHAIN'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chaîne réservation - DA - commande d''achat'
@Analytics.dataCategory: #CUBE

define view ZI_ResaChainCube
  as select from I_PurchaseRequisitionItem as PurReqItem

    left outer join I_SalesOrderItem as SalesItem
      on  PurReqItem.SalesOrder     = SalesItem.SalesOrder
      and PurReqItem.SalesOrderItem = SalesItem.SalesOrderItem

    left outer join I_PurchaseOrderItem as PoItem
      on  PurReqItem.PurchaseOrder     = PoItem.PurchaseOrder
      and PurReqItem.PurchaseOrderItem = PoItem.PurchaseOrderItem
{
  key PurReqItem.PurchaseRequisition,
  key PurReqItem.PurchaseRequisitionItem,

      -- origine : réservation magasin transmise par IDoc
      PurReqItem.ZZReservation                   as Reservation,

      -- origine : commande client individuelle
      PurReqItem.SalesOrder,
      PurReqItem.SalesOrderItem,
      SalesItem.SalesOrderItemText,

      -- aval : commande d'achat
      PurReqItem.PurchaseOrder,
      PurReqItem.PurchaseOrderItem,

      PurReqItem.Plant,
      PurReqItem.PurchasingGroup,
      PurReqItem.Material,
      PurReqItem.PurchaseRequisitionItemText,
      PurReqItem.PurchaseRequisitionReleaseDate as PurReqDate,
      PoItem.PurchaseOrderItemText,

      -- origine du poste
      case when PurReqItem.ZZReservation <> '' then 'RESA'
           when PurReqItem.SalesOrder    <> '' then 'VENT'
           else                                     'AUTR'
      end                                        as OriginType,

      -- étape atteinte dans la chaîne
      case when PurReqItem.PurchaseOrder <> '' then 'PO'
           else                                     'PR'
      end                                        as ChainStage,

      -- mesures
      1                                          as PurReqItemCount,

      case when PurReqItem.PurchaseOrder <> ''
           then 1 else 0 end                     as ConvertedItemCount,

      case when PurReqItem.PurchaseOrder =  ''
           then 1 else 0 end                     as OpenItemCount,

      case when PurReqItem.PurchaseOrder <> ''
           then 3 else 2 end                     as ChainCriticality,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      PurReqItem.RequestedQuantity,
      PurReqItem.BaseUnit,

      @Semantics.amount.currencyCode: 'Currency'
      PurReqItem.PurchaseRequisitionPrice        as ItemAmount,
      PurReqItem.Currency
}
```

| Champ calculé | Usage |
|---|---|
| `OriginType` | Distingue les postes issus des réservations de ceux issus des ventes |
| `ChainStage` | Étape atteinte : demande seule ou commande créée |
| `ConvertedItemCount` | Mesure de conversion |
| `OpenItemCount` | Mesure du reste à convertir |
| `ChainCriticality` | Couleur selon l'avancement |

> **📸 COPIE D'ÉCRAN N°07** — Eclipse ADT : cube de la chaîne, code source
> *Remplacer cette ligne par :* `![Copie 07](images/RESA-COCKPIT/capture-07.png)`

> **📸 COPIE D'ÉCRAN N°08** — Eclipse ADT : aperçu de données du cube
> *Remplacer cette ligne par :* `![Copie 08](images/RESA-COCKPIT/capture-08.png)`

> **⚠️ À vérifier impérativement**
> Le nom du champ de réservation et les noms des champs de référence vers la commande client et la commande d'achat dans la vue standard des postes de demande d'achat. Les relever dans Eclipse avant activation : ils conditionnent la totalité du modèle.

---

### A4 — Requête analytique de la chaîne

Cette requête alimente les indicateurs de conversion de l'Overview Page.

```abap
@AbapCatalog.sqlViewName: 'ZCRESAKPI'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Requête cockpit - chaîne réservations'
@Analytics.query: true
@OData.publish: true

define view ZC_ResaChainQuery
  as select from ZI_ResaChainCube
{
  @AnalyticsDetails.query.axis: #ROWS
  @EndUserText.label: 'Division'
  Plant,

  @AnalyticsDetails.query.axis: #ROWS
  @EndUserText.label: 'Groupe d''acheteurs'
  PurchasingGroup,

  @AnalyticsDetails.query.axis: #FREE
  @EndUserText.label: 'Origine'
  OriginType,

  @AnalyticsDetails.query.axis: #FREE
  @EndUserText.label: 'Étape'
  ChainStage,

  @AnalyticsDetails.query.axis: #FREE
  PurReqDate,

  @DefaultAggregation: #SUM
  @EndUserText.label: 'Postes de DA'
  PurReqItemCount,

  @DefaultAggregation: #SUM
  @EndUserText.label: 'Postes convertis'
  ConvertedItemCount,

  @DefaultAggregation: #SUM
  @EndUserText.label: 'Postes en attente'
  OpenItemCount,

  @DefaultAggregation: #SUM
  @Semantics.amount.currencyCode: 'Currency'
  @EndUserText.label: 'Montant'
  ItemAmount,

  Currency,

  @AnalyticsDetails.query.formula: 'case when $projection.PurReqItemCount > 0 then $projection.ConvertedItemCount / $projection.PurReqItemCount * 100 else 0 end'
  @EndUserText.label: 'Taux de conversion'
  1 as ConversionRate
}
```

> **📸 COPIE D'ÉCRAN N°09** — Eclipse ADT : requête analytique de la chaîne
> *Remplacer cette ligne par :* `![Copie 09](images/RESA-COCKPIT/capture-09.png)`

---

### A5 — Requête analytique d'intégration

Cette seconde requête porte sur le modèle des IDocs. Elle est séparée de la précédente pour la raison exposée au chapitre 1.3 : les deux modèles ne se joignent pas.

```abap
@AbapCatalog.sqlViewName: 'ZCRESAIDKPI'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Requête cockpit - intégration des réservations'
@Analytics.query: true
@OData.publish: true

define view ZC_ResaIdocQuery
  as select from ZI_ResaIdocMonitor
{
  @AnalyticsDetails.query.axis: #ROWS
  @EndUserText.label: 'Magasin émetteur'
  SenderPartner,

  @AnalyticsDetails.query.axis: #FREE
  @EndUserText.label: 'Statut d''intégration'
  IntegrationStatus,

  @AnalyticsDetails.query.axis: #FREE
  CreationDate,

  @DefaultAggregation: #SUM
  @EndUserText.label: 'IDocs reçus'
  IDocCount,

  @DefaultAggregation: #SUM
  @EndUserText.label: 'IDocs en erreur'
  IDocErrorCount,

  @AnalyticsDetails.query.formula: 'case when $projection.IDocCount > 0 then ( $projection.IDocCount - $projection.IDocErrorCount ) / $projection.IDocCount * 100 else 0 end'
  @EndUserText.label: 'Taux d''intégration'
  1 as IntegrationRate
}
```

> **📸 COPIE D'ÉCRAN N°10** — Eclipse ADT : requête analytique d'intégration
> *Remplacer cette ligne par :* `![Copie 10](images/RESA-COCKPIT/capture-10.png)`

---

### A6 — Vue de consommation détaillée

Cette vue alimente le List Report. Elle n'agrège rien : elle restitue une ligne par poste, avec la totalité de la chaîne.

```abap
@AbapCatalog.sqlViewName: 'ZCRESATRACK'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Suivi détaillé de la chaîne'
@Metadata.allowExtensions: true
@OData.publish: true
@Search.searchable: true

define view ZC_ResaChainTracking
  as select from ZI_ResaChainCube
{
  @Search.defaultSearchElement: true
  key PurchaseRequisition,
  key PurchaseRequisitionItem,

      @Search.defaultSearchElement: true
      Reservation,

      @Search.defaultSearchElement: true
      SalesOrder,
      SalesOrderItem,
      SalesOrderItemText,

      PurchaseOrder,
      PurchaseOrderItem,
      PurchaseOrderItemText,

      OriginType,
      ChainStage,
      ChainCriticality,

      Plant,
      PurchasingGroup,
      Material,
      PurchaseRequisitionItemText,
      PurReqDate,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      RequestedQuantity,
      BaseUnit,

      @Semantics.amount.currencyCode: 'Currency'
      ItemAmount,
      Currency
}
```

> **📸 COPIE D'ÉCRAN N°11** — Eclipse ADT : vue de consommation détaillée
> *Remplacer cette ligne par :* `![Copie 11](images/RESA-COCKPIT/capture-11.png)`

---

### A7 — Annoter les indicateurs et le List Report

#### A7.1 Indicateurs de l'Overview Page

```abap
@Metadata.layer: #CORE

@UI.chart: [ { qualifier:  'AttenteParDivision',
               chartType:  #COLUMN,
               dimensions: [ 'Plant' ],
               measures:   [ 'OpenItemCount' ],
               dimensionAttributes: [ { dimension: 'Plant', role: #CATEGORY } ],
               measureAttributes:   [ { measure: 'OpenItemCount',
                                        role: #AXIS_1, asDataPoint: true } ] } ]

@UI.selectionVariant: [ { qualifier: 'Reservations',
                          text: 'Postes issus des réservations magasin',
                          parameters: [ { name: 'OriginType', value: 'RESA' } ] } ]

@UI.presentationVariant: [ { qualifier: 'ParDivision',
                             sortOrder: [ { by: 'OpenItemCount', direction: #DESC } ],
                             visualizations: [ { type: #AS_CHART,
                                                 qualifier: 'AttenteParDivision' } ] } ]

annotate view ZC_ResaChainQuery with
{
  @UI.dataPoint: { qualifier: 'PostesEnAttente',
                   title:     'Postes en attente de commande',
                   criticalityCalculation: {
                     improvementDirection:     #MINIMIZE,
                     toleranceRangeHighValue:  50,
                     deviationRangeHighValue: 150 } }
  OpenItemCount;

  @UI.dataPoint: { qualifier:   'TauxConversion',
                   title:       'Taux de conversion en commande',
                   targetValue: 95,
                   criticalityCalculation: {
                     improvementDirection:   #MAXIMIZE,
                     toleranceRangeLowValue: 85,
                     deviationRangeLowValue: 70 } }
  ConversionRate;
}
```

> **📸 COPIE D'ÉCRAN N°12** — Eclipse ADT : extension de métadonnées des indicateurs
> *Remplacer cette ligne par :* `![Copie 12](images/RESA-COCKPIT/capture-12.png)`

#### A7.2 Colonnes et page objet du List Report

Les trois groupes de champs reconstituent visuellement la chaîne : origine, demande, commande. L'utilisateur lit le parcours du dossier de haut en bas.

```abap
@Metadata.layer: #CORE

@UI.headerInfo: { typeName:       'Poste de la chaîne',
                  typeNamePlural: 'Suivi des réservations',
                  title:       { type: #STANDARD, value: 'PurchaseRequisition' },
                  description: { value: 'PurchaseRequisitionItemText' } }

@UI.facet: [ { id: 'Origine', purpose: #STANDARD,
               type: #FIELDGROUP_REFERENCE, targetQualifier: 'GrpOrigine',
               label: 'Origine de la demande', position: 10 },
             { id: 'Demande', purpose: #STANDARD,
               type: #FIELDGROUP_REFERENCE, targetQualifier: 'GrpDemande',
               label: 'Demande d''achat', position: 20 },
             { id: 'Commande', purpose: #STANDARD,
               type: #FIELDGROUP_REFERENCE, targetQualifier: 'GrpCommande',
               label: 'Commande d''achat', position: 30 } ]

annotate view ZC_ResaChainTracking with
{
  @UI.hidden: true
  ChainCriticality;

  @UI: { lineItem:       [ { position: 10, label: 'Réservation', importance: #HIGH } ],
         selectionField: [ { position: 10 } ] }
  @UI.fieldGroup: [ { qualifier: 'GrpOrigine', position: 10 } ]
  Reservation;

  @UI: { lineItem:       [ { position: 20, label: 'Commande client' } ],
         selectionField: [ { position: 20 } ] }
  @UI.fieldGroup: [ { qualifier: 'GrpOrigine', position: 20 } ]
  SalesOrder;

  @UI.fieldGroup: [ { qualifier: 'GrpOrigine', position: 30 } ]
  SalesOrderItem;

  @UI: { lineItem:       [ { position: 30, label: 'Demande d''achat', importance: #HIGH } ],
         selectionField: [ { position: 30 } ] }
  @UI.fieldGroup: [ { qualifier: 'GrpDemande', position: 10 } ]
  PurchaseRequisition;

  @UI.fieldGroup: [ { qualifier: 'GrpDemande', position: 20 } ]
  PurchaseRequisitionItem;

  @UI: { lineItem: [ { position: 40, label: 'Date de DA' } ] }
  @UI.fieldGroup: [ { qualifier: 'GrpDemande', position: 30 } ]
  PurReqDate;

  @UI: { lineItem:       [ { position: 50, label: 'Commande d''achat',
                             criticality: 'ChainCriticality', importance: #HIGH } ],
         selectionField: [ { position: 40 } ] }
  @UI.fieldGroup: [ { qualifier: 'GrpCommande', position: 10 } ]
  PurchaseOrder;

  @UI.fieldGroup: [ { qualifier: 'GrpCommande', position: 20 } ]
  PurchaseOrderItem;

  @UI: { lineItem:       [ { position: 60, label: 'Étape' } ],
         selectionField: [ { position: 50 } ] }
  ChainStage;

  @UI: { lineItem:       [ { position: 70, label: 'Division' } ],
         selectionField: [ { position: 60 } ] }
  Plant;

  @UI: { lineItem: [ { position: 80, label: 'Article', importance: #LOW } ] }
  Material;

  @UI: { lineItem: [ { position: 90, label: 'Montant' } ] }
  ItemAmount;
}
```

> **📸 COPIE D'ÉCRAN N°13** — Eclipse ADT : extension de métadonnées du List Report
> *Remplacer cette ligne par :* `![Copie 13](images/RESA-COCKPIT/capture-13.png)`

#### A7.3 Colonnes du monitoring IDoc

```abap
@Metadata.layer: #CORE

annotate view ZC_ResaIdocTracking with
{
  @UI.hidden: true
  StatusCriticality;

  @UI: { lineItem:       [ { position: 10, label: 'N° IDoc', importance: #HIGH } ],
         selectionField: [ { position: 10 } ] }
  IDocNumber;

  @UI: { lineItem:       [ { position: 20, label: 'Magasin', importance: #HIGH } ],
         selectionField: [ { position: 20 } ] }
  SenderPartner;

  @UI: { lineItem:       [ { position: 30, label: 'Statut',
                             criticality: 'StatusCriticality', importance: #HIGH } ],
         selectionField: [ { position: 30 } ] }
  @UI.textArrangement: #TEXT_ONLY
  IDocStatus;

  @UI: { lineItem: [ { position: 40, label: 'Date de réception' } ] }
  CreationDate;

  @UI: { lineItem: [ { position: 50, label: 'Message d''erreur' } ] }
  MessageText;
}
```

> **📸 COPIE D'ÉCRAN N°14** — Eclipse ADT : extension de métadonnées du monitoring IDoc
> *Remplacer cette ligne par :* `![Copie 14](images/RESA-COCKPIT/capture-14.png)`

---

### A8 — Publier et tester les services

1. Activer l'ensemble des vues dans l'ordre des dépendances.
2. Vérifier la génération des services par l'annotation de publication.
3. Lancer la transaction `/IWFND/MAINT_SERVICE` et enregistrer chaque service.
4. Contrôler que le statut ICF est actif pour chacun.
5. Tester les métadonnées et une lecture agrégée pour chaque service.
6. Rejouer les tests depuis un navigateur, par la route d'accès des utilisateurs.
7. Relever les noms exacts des services : ils seront repris dans les descripteurs.

| Service | Usage |
|---|---|
| Requête de la chaîne | Cartes de conversion de l'Overview Page |
| Requête d'intégration | Carte d'intégration de l'Overview Page |
| Vue de consommation détaillée | List Report et carte de liste |

> **📸 COPIE D'ÉCRAN N°15** — Transaction `/IWFND/MAINT_SERVICE` : les trois services enregistrés et actifs
> *Remplacer cette ligne par :* `![Copie 15](images/RESA-COCKPIT/capture-15.png)`

> **📸 COPIE D'ÉCRAN N°16** — Navigateur : lecture agrégée par la route des utilisateurs
> *Remplacer cette ligne par :* `![Copie 16](images/RESA-COCKPIT/capture-16.png)`

#### Critères de validation de la partie A

- Chaque vue est activée et son aperçu de données est cohérent.
- Le nombre d'IDocs correspond à un comptage de contrôle dans les transactions standard.
- Le nombre de postes correspond à un comptage de contrôle sur la demande d'achat.
- Les trois services répondent par la route d'accès des utilisateurs.

---

## Partie B — Overview Page

### B1 — Générer le projet

1. Ouvrir VS Code et lancer le générateur d'application SAP Fiori.
2. Choisir le modèle Overview Page.
3. Sélectionner le service de la requête de la chaîne comme source principale.
4. Sélectionner l'entité de filtre global.
5. Renseigner nom du module, titre et espace de noms.
6. Renseigner la configuration Launchpad du cockpit.
7. Sélectionner la version SAPUI5 correspondant à celle du système cible.
8. Terminer la génération.

> **📸 COPIE D'ÉCRAN N°17** — VS Code : générateur, modèle Overview Page et service principal
> *Remplacer cette ligne par :* `![Copie 17](images/RESA-COCKPIT/capture-17.png)`

> **⚠️ Version SAPUI5**
> Sélectionner la version du système, et non la plus récente proposée. Une application générée pour une version postérieure fonctionne en local et échoue une fois déployée.

---

### B2 — Déclarer les trois sources de données

Le cockpit interroge trois services distincts. Chacun est déclaré comme source de données et associé à un modèle, que les cartes référencent ensuite.

```json
"sap.app": {
  "id": "zovp.resacockpit",
  "dataSources": {
    "mainService": {
      "uri": "/sap/opu/odata/sap/ZCRESAKPI_CDS/",
      "type": "OData",
      "settings": { "odataVersion": "2.0" }
    },
    "idocService": {
      "uri": "/sap/opu/odata/sap/ZCRESAIDKPI_CDS/",
      "type": "OData",
      "settings": { "odataVersion": "2.0" }
    },
    "trackingService": {
      "uri": "/sap/opu/odata/sap/ZCRESATRACK_CDS/",
      "type": "OData",
      "settings": { "odataVersion": "2.0" }
    }
  },
  "crossNavigation": {
    "inbounds": {
      "cockpit-display": {
        "semanticObject": "ResaCockpit",
        "action": "display",
        "title": "Cockpit réservations magasin",
        "icon": "sap-icon://business-objects-experience",
        "signature": { "parameters": {}, "additionalParameters": "allowed" }
      }
    }
  }
},

"sap.ui5": {
  "models": {
    "mainModel":     { "dataSource": "mainService",     "settings": { "defaultCountMode": "Inline" } },
    "idocModel":     { "dataSource": "idocService",     "settings": { "defaultCountMode": "Inline" } },
    "trackingModel": { "dataSource": "trackingService", "settings": { "defaultCountMode": "Inline" } }
  }
}
```

> **📸 COPIE D'ÉCRAN N°18** — VS Code : descripteur, sources de données et modèles
> *Remplacer cette ligne par :* `![Copie 18](images/RESA-COCKPIT/capture-18.png)`

---

### B3 — Configurer les cartes

Cinq cartes composent le cockpit. Chacune déclare le modèle qu'elle interroge, ce qui permet de faire cohabiter les trois services dans une même page.

```json
"sap.ovp": {
  "globalFilterModel": "mainModel",
  "globalFilterEntityType": "ZC_ResaChainQueryType",
  "containerLayout": "resizable",
  "enableLiveFilter": true,
  "considerAnalyticalParameters": true,
  "cards": {

    "card01_attente": {
      "model": "mainModel",
      "template": "sap.ovp.cards.charts.analytical",
      "settings": {
        "title": "Postes en attente de commande",
        "subTitle": "Par division",
        "entitySet": "ZC_ResaChainQuery",
        "chartAnnotationPath": "com.sap.vocabularies.UI.v1.Chart#AttenteParDivision",
        "dataPointAnnotationPath": "com.sap.vocabularies.UI.v1.DataPoint#PostesEnAttente",
        "presentationAnnotationPath": "com.sap.vocabularies.UI.v1.PresentationVariant#ParDivision"
      }
    },

    "card02_conversion": {
      "model": "mainModel",
      "template": "sap.ovp.cards.charts.analytical",
      "settings": {
        "title": "Taux de conversion en commande",
        "entitySet": "ZC_ResaChainQuery",
        "dataPointAnnotationPath": "com.sap.vocabularies.UI.v1.DataPoint#TauxConversion",
        "selectionAnnotationPath": "com.sap.vocabularies.UI.v1.SelectionVariant#Reservations"
      }
    },

    "card03_idoc": {
      "model": "idocModel",
      "template": "sap.ovp.cards.charts.analytical",
      "settings": {
        "title": "Intégration des réservations",
        "subTitle": "IDocs en erreur par magasin",
        "entitySet": "ZC_ResaIdocQuery",
        "chartAnnotationPath": "com.sap.vocabularies.UI.v1.Chart#ErreursParMagasin",
        "dataPointAnnotationPath": "com.sap.vocabularies.UI.v1.DataPoint#IDocsEnErreur"
      }
    },

    "card04_liste": {
      "model": "trackingModel",
      "template": "sap.ovp.cards.list",
      "settings": {
        "title": "Postes les plus anciens en attente",
        "listType": "extended",
        "listFlavor": "standard",
        "entitySet": "ZC_ResaChainTracking",
        "annotationPath": "com.sap.vocabularies.UI.v1.LineItem",
        "identificationAnnotationPath": "com.sap.vocabularies.UI.v1.Identification"
      }
    },

    "card05_liens": {
      "model": "trackingModel",
      "template": "sap.ovp.cards.linklist",
      "settings": {
        "title": "Accès rapides",
        "listFlavor": "standard",
        "staticContent": [
          {
            "title": "Suivi détaillé de la chaîne",
            "subTitle": "Réservation, DA, commande",
            "imageUri": "sap-icon://tree",
            "semanticObject": "ResaChain",
            "action": "track"
          },
          {
            "title": "Monitoring des IDocs",
            "subTitle": "Réservations en erreur",
            "imageUri": "sap-icon://message-error",
            "semanticObject": "ResaIdoc",
            "action": "monitor"
          },
          {
            "title": "Conversion automatique en commandes",
            "subTitle": "Transaction ME59N",
            "imageUri": "sap-icon://sales-order",
            "semanticObject": "PurchaseRequisition",
            "action": "convertAuto"
          }
        ]
      }
    }
  }
}
```

| Carte | Modèle | Contenu |
|---|---|---|
| `card01` | Chaîne | Postes en attente par division |
| `card02` | Chaîne | Taux de conversion, seuils |
| `card03` | Intégration | IDocs en erreur par magasin |
| `card04` | Suivi détaillé | Postes les plus anciens |
| `card05` | Suivi détaillé | Accès rapides aux applications |

> **📸 COPIE D'ÉCRAN N°19** — VS Code : configuration des cartes
> *Remplacer cette ligne par :* `![Copie 19](images/RESA-COCKPIT/capture-19.png)`

> **📸 COPIE D'ÉCRAN N°20** — Navigateur : cockpit complet exécuté en local
> *Remplacer cette ligne par :* `![Copie 20](images/RESA-COCKPIT/capture-20.png)`

> **ℹ️ Filtre global et modèles multiples**
> Le filtre global ne s'applique qu'aux cartes dont le modèle porte les champs filtrés. Les cartes des autres modèles ne réagissent pas. C'est le comportement attendu, mais il doit être expliqué aux utilisateurs pour éviter les demandes d'évolution mal fondées.

---

## Partie C — List Report de suivi détaillé

### C1 — Générer le projet

1. Lancer le générateur d'application SAP Fiori.
2. Choisir le modèle de liste avec page de détail.
3. Sélectionner le service de la vue de consommation détaillée.
4. Sélectionner l'entité principale.
5. Renseigner la configuration Launchpad propre à cette application.
6. Sélectionner la version SAPUI5 du système cible.
7. Exécuter en local et contrôler le rendu.

> **📸 COPIE D'ÉCRAN N°21** — VS Code : génération du List Report
> *Remplacer cette ligne par :* `![Copie 21](images/RESA-COCKPIT/capture-21.png)`

> **📸 COPIE D'ÉCRAN N°22** — Navigateur : liste de suivi de la chaîne
> *Remplacer cette ligne par :* `![Copie 22](images/RESA-COCKPIT/capture-22.png)`

---

### C2 — Vérifier la page objet

La page objet a été décrite par les annotations de la partie A. Elle présente le dossier en trois sections successives, qui reconstituent le parcours.

| Section | Contenu |
|---|---|
| Origine de la demande | Numéro de réservation, commande client et poste |
| Demande d'achat | Numéro, poste, date de demande |
| Commande d'achat | Numéro et poste, vides si non convertie |

> **📸 COPIE D'ÉCRAN N°23** — Navigateur : page objet, les trois sections de la chaîne
> *Remplacer cette ligne par :* `![Copie 23](images/RESA-COCKPIT/capture-23.png)`

---

### C3 — Vérifier filtres et recherche

1. Tester la recherche libre sur un numéro de réservation.
2. Tester le filtre sur l'étape atteinte et vérifier la restriction des résultats.
3. Tester le filtre sur la division.
4. Enregistrer une variante de filtre et vérifier sa restitution.
5. Contrôler le tri par colonne.

> **📸 COPIE D'ÉCRAN N°24** — Navigateur : recherche libre sur un numéro de réservation
> *Remplacer cette ligne par :* `![Copie 24](images/RESA-COCKPIT/capture-24.png)`

> **📸 COPIE D'ÉCRAN N°25** — Navigateur : filtre sur l'étape de la chaîne
> *Remplacer cette ligne par :* `![Copie 25](images/RESA-COCKPIT/capture-25.png)`

---

## Partie D — Navigation

### D1 — Cartographie des navigations

| Depuis | Vers | Mécanisme |
|---|---|---|
| Cockpit | Suivi détaillé | Carte de liens, objet sémantique dédié |
| Cockpit | Monitoring des IDocs | Carte de liens, objet sémantique dédié |
| Cockpit | ME59N | Carte de liens, target mapping de transaction |
| Carte de liste | Page objet du suivi | Navigation par annotation d'identification |
| Page objet | Fiche de la demande d'achat | Navigation intentionnelle |
| Page objet | Fiche de la commande d'achat | Navigation intentionnelle |

---

### D2 — Navigation vers les objets standard

Depuis la page objet, l'utilisateur doit pouvoir ouvrir la demande et la commande d'achat réelles.

```abap
@Metadata.layer: #CORE

annotate view ZC_ResaChainTracking with
{
  @UI.identification: [ { position: 10,
                          type: #WITH_INTENT_BASED_NAVIGATION,
                          semanticObject: 'PurchaseRequisition',
                          semanticObjectAction: 'displayFactSheet',
                          label: 'Afficher la demande d''achat' } ]
  PurchaseRequisition;

  @UI.identification: [ { position: 20,
                          type: #WITH_INTENT_BASED_NAVIGATION,
                          semanticObject: 'PurchaseOrder',
                          semanticObjectAction: 'displayFactSheet',
                          label: 'Afficher la commande d''achat' } ]
  PurchaseOrder;
}
```

> **📸 COPIE D'ÉCRAN N°26** — Navigateur : navigation de la page objet vers la demande d'achat
> *Remplacer cette ligne par :* `![Copie 26](images/RESA-COCKPIT/capture-26.png)`

> **ℹ️ Relevé préalable**
> Les objets sémantiques et actions des fiches standard se relèvent dans le Launchpad Designer, dans les catalogues livrés par SAP. Ne pas les deviner : une valeur erronée produit un lien qui ne se résout pas, sans message explicite.

---

### D3 — Target mapping vers ME59N

1. Ouvrir le Launchpad Designer et le catalogue Z du projet.
2. Créer un target mapping avec l'objet sémantique et l'action retenus.
3. Choisir le type d'application Transaction.
4. Renseigner le code de transaction et l'alias système.
5. Enregistrer et contrôler la présence dans le catalogue.

> **📸 COPIE D'ÉCRAN N°27** — Launchpad Designer : target mapping de type transaction
> *Remplacer cette ligne par :* `![Copie 27](images/RESA-COCKPIT/capture-27.png)`

---

### D4 — Tester les navigations

1. Vérifier que chaque application cible s'ouvre depuis sa propre tuile.
2. Tester chaque entrée de la carte d'accès rapides.
3. Tester la navigation depuis la carte de liste vers la page objet.
4. Tester les navigations de la page objet vers les fiches standard.
5. Vérifier le retour au cockpit après chaque navigation.
6. Rejouer avec un utilisateur ne disposant pas des catalogues cibles.

> **📸 COPIE D'ÉCRAN N°28** — Launchpad : enchaînement cockpit vers suivi détaillé
> *Remplacer cette ligne par :* `![Copie 28](images/RESA-COCKPIT/capture-28.png)`

---

## Partie E — Déploiement et publication

### E1 — Déployer les deux applications

1. Configurer le déploiement de chaque application : repository, package, ordre de transport.
2. Exécuter un déploiement en mode test pour chacune.
3. Déployer réellement.
4. Vérifier la création des applications BSP.
5. Activer les nœuds ICF correspondants.
6. Appeler chaque application directement par son URL.

> **📸 COPIE D'ÉCRAN N°29** — VS Code : journal de déploiement des applications
> *Remplacer cette ligne par :* `![Copie 29](images/RESA-COCKPIT/capture-29.png)`

> **📸 COPIE D'ÉCRAN N°30** — Transaction `SICF` : nœuds ICF des deux applications activés
> *Remplacer cette ligne par :* `![Copie 30](images/RESA-COCKPIT/capture-30.png)`

---

### E2 — Publier les tuiles

1. Créer ou compléter le catalogue Z du projet.
2. Créer la tuile du cockpit et son target mapping.
3. Créer la tuile du suivi détaillé et son target mapping.
4. Créer la tuile du monitoring IDoc si elle doit être accessible directement.
5. Vérifier que le catalogue contient l'ensemble des tuiles et des target mappings, y compris celui de la transaction.

> **📸 COPIE D'ÉCRAN N°31** — Launchpad Designer : contenu complet du catalogue du projet
> *Remplacer cette ligne par :* `![Copie 31](images/RESA-COCKPIT/capture-31.png)`

---

### E3 — Rôles et autorisations

| Autorisation | Portée |
|---|---|
| Services OData des trois modèles | Exécution des services, objet de service |
| Données de demande d'achat | Objets du domaine achat, périmètre organisationnel |
| Transaction de conversion | Autorisation de transaction |
| Catalogues des cibles de navigation | Résolution des intentions |
| Consultation des IDocs | Selon la politique de sécurité du projet |

1. Ajouter au rôle le catalogue du projet et les catalogues des cibles.
2. Ajouter le groupe ou l'espace contenant les tuiles.
3. Compléter les autorisations listées ci-dessus.
4. Générer le profil et affecter le rôle à l'utilisateur de test.
5. Invalider les caches du Launchpad.
6. Vérifier l'affichage et le fonctionnement de bout en bout.

> **📸 COPIE D'ÉCRAN N°32** — Transaction `PFCG` : rôle du cockpit et autorisations
> *Remplacer cette ligne par :* `![Copie 32](images/RESA-COCKPIT/capture-32.png)`

> **📸 COPIE D'ÉCRAN N°33** — Launchpad : cockpit et suivi détaillé accessibles
> *Remplacer cette ligne par :* `![Copie 33](images/RESA-COCKPIT/capture-33.png)`

> **⚠️ Sensibilité des données IDoc**
> Le monitoring expose des messages d'erreur techniques qui peuvent contenir des informations de gestion. Restreindre l'accès à cette application aux profils qui en ont l'usage plutôt que de l'ouvrir largement.

---

## Partie F — Recette, transport et exploitation

### F1 — Fiche de recette

| N° | Point de contrôle | Résultat attendu | OK / KO |
|---|---|---|---|
| 1 | Champ de réservation visible dans la vue standard | Présent | ☐ |
| 2 | Vue du dernier statut : un IDoc par ligne | Sans doublon | ☐ |
| 3 | Regroupement des statuts conforme au relevé | Conforme | ☐ |
| 4 | Comptage des IDocs conforme aux transactions standard | Conforme | ☐ |
| 5 | Cube : origine correctement déterminée | Conforme | ☐ |
| 6 | Cube : étape de la chaîne correcte | Conforme | ☐ |
| 7 | Comptage des postes conforme à un contrôle | Conforme | ☐ |
| 8 | Trois services enregistrés et actifs | Statut vert | ☐ |
| 9 | Services accessibles par la route des utilisateurs | HTTP 200 | ☐ |
| 10 | Toutes les cartes affichent des données | Aucune carte vide | ☐ |
| 11 | Seuils et couleurs des indicateurs | Conformes | ☐ |
| 12 | Carte d'intégration alimentée | Conforme | ☐ |
| 13 | List Report : colonnes et ordre | Conformes | ☐ |
| 14 | Page objet : trois sections de la chaîne | Conformes | ☐ |
| 15 | Recherche libre sur numéro de réservation | Fonctionnelle | ☐ |
| 16 | Filtres sur étape et division | Fonctionnels | ☐ |
| 17 | Navigation cockpit vers suivi détaillé | Fonctionnelle | ☐ |
| 18 | Navigation vers les fiches standard | Fonctionnelle | ☐ |
| 19 | Navigation vers la transaction de conversion | Fonctionnelle | ☐ |
| 20 | Temps de réponse sur volume réel | Acceptable | ☐ |
| 21 | Comportement pour un utilisateur d'un autre périmètre | Conforme | ☐ |

> **📸 COPIE D'ÉCRAN N°34** — Synthèse de recette : cockpit et suivi détaillé en fonctionnement
> *Remplacer cette ligne par :* `![Copie 34](images/RESA-COCKPIT/capture-34.png)`

### F2 — Transport

| Objet | Mode de propagation |
|---|---|
| Vues CDS et extensions de métadonnées | Ordre de workbench |
| Services OData générés | Ordre de workbench ; enregistrement à contrôler à l'arrivée |
| Applications déployées | Ordre de workbench ; activation ICF manuelle |
| Catalogue, tuiles et target mappings | Ordre de customizing |
| Rôle PFCG | Ordre de customizing |

> **⚠️ Après import**
> Activer les nœuds ICF, enregistrer les trois services, invalider les caches, puis rejouer la fiche de recette. Vérifier en particulier que les target mappings des cibles standard existent dans le système d'arrivée.

### F3 — Exploitation

| Sujet | Point de vigilance |
|---|---|
| Volume des IDocs | La table des statuts croît vite ; prévoir l'archivage |
| Performance du monitoring | Restreindre par variante de sélection sur une période |
| Nouveaux statuts | Un statut non prévu fausse le taux d'intégration |
| Évolution du module d'entrée | Revalider le rattachement par le numéro de réservation |
| Évolution des vues standard | Retester le cube après montée de version |
| Cohérence des chiffres | Rapprocher périodiquement d'une extraction de contrôle |

---

## Annexe A — Diagnostic des incidents fréquents

| Symptôme | Cause probable | Action corrective |
|---|---|---|
| Les IDocs apparaissent en double | Jointure sur les statuts sans filtrer le dernier | Contrôler l'usage de la vue du dernier statut |
| Le champ de réservation est vide | Champ non exposé dans la vue CDS standard | Étendre la vue standard, voir le mode opératoire d'extension |
| Le taux d'intégration est incohérent | Statut non prévu dans le regroupement | Compléter le regroupement selon le relevé réel |
| Une carte reste vide | Chemin d'annotation erroné | Comparer avec le qualificateur défini en CDS |
| Le filtre global n'agit pas sur une carte | Carte reposant sur un autre modèle | Comportement normal, à expliquer aux utilisateurs |
| Les postes issus des ventes n'apparaissent pas | Champ de commande client non renseigné | Contrôler le flux de commande client individuelle |
| La navigation vers une fiche échoue | Objet sémantique erroné ou catalogue non affecté | Relever la valeur réelle et compléter le rôle |
| Le List Report est lent | Volume non restreint | Ajouter une variante de sélection par défaut |
| Le cockpit ne se charge pas après déploiement | Version SAPUI5 incompatible | Contrôler la version minimale du descripteur |
| Les montants s'affichent sans devise | Annotation de sémantique absente | Compléter l'annotation de devise dans le cube |

---

## Annexe B — Index des copies d'écran

| N° | Chapitre | Contenu attendu |
|---|---|---|
| 01 à 03 | Chapitre 2 | Prérequis, route OData, statuts IDoc |
| 04 | Étape A1 | Vue du dernier statut |
| 05 à 06 | Étape A2 | Monitoring des IDocs |
| 07 à 08 | Étape A3 | Cube de la chaîne |
| 09 à 10 | Étapes A4 et A5 | Requêtes analytiques |
| 11 | Étape A6 | Vue de consommation détaillée |
| 12 à 14 | Étape A7 | Extensions de métadonnées |
| 15 à 16 | Étape A8 | Services publiés et testés |
| 17 à 20 | Partie B | Overview Page |
| 21 à 25 | Partie C | List Report et page objet |
| 26 à 28 | Partie D | Navigation |
| 29 à 33 | Partie E | Déploiement, tuiles et rôles |
| 34 | Partie F | Synthèse de recette |

---

## Annexe C — Historique des versions

| Version | Date | Auteur | Nature des modifications |
|---|---|---|---|
| 1.0 | … | … | Création du document |
| | | | |