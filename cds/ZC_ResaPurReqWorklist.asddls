@AbapCatalog.sqlViewName: 'ZCRESAWRKLST'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Liste de travail - postes de DA à approvisionner'
@Metadata.allowExtensions: true
@OData.publish: true
@Search.searchable: true

-- Liste de travail commune aux deux alternatives : un poste de demande d'achat par ligne,
-- avec le nombre de sources candidates et la source retenue.
-- Le périmètre affiché n'est PAS filtré ici : chaque application applique sa propre
-- variante de sélection (Alternative 1 : toutes les DA ; Alternative 2 : réservations).
define view ZC_ResaPurReqWorklist
  as select from    ZI_ResaChainCube as Item

    left outer join ztresa_srcsel    as Selection   -- TODO : table de travail du choix de source
      on  Selection.banfn = Item.PurchaseRequisition
      and Selection.bnfpo = Item.PurchaseRequisitionItem

    association [0..*] to ZC_ResaSourceOption as _SourceOption
      on  _SourceOption.PurchaseRequisition     = $projection.PurchaseRequisition
      and _SourceOption.PurchaseRequisitionItem = $projection.PurchaseRequisitionItem
{
      @Search.defaultSearchElement: true
  key Item.PurchaseRequisition,
  key Item.PurchaseRequisitionItem,

      @Search.defaultSearchElement: true
      Item.Reservation,

      @ObjectModel.text.element: [ 'OriginTypeText' ]
      Item.OriginType,
      Item.OriginTypeText,

      Item.Plant,
      Item.PurchasingGroup,

      @Search.defaultSearchElement: true
      Item.Material,
      Item.PurchaseRequisitionItemText,
      Item.PurReqDate,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Item.RequestedQuantity,
      Item.BaseUnit,

      @Semantics.amount.currencyCode: 'Currency'
      Item.ItemAmount,
      Item.Currency,

      -- aval : commande d'achat ou commande petite caisse
      Item.PurchaseOrder,
      Item.FollowOnDocument,
      Item.FollowOnDocumentType,

      @ObjectModel.text.element: [ 'ChainStageText' ]
      Item.ChainStage,
      Item.ChainStageText,

      -- source retenue
      cast( Selection.srctype as abap.char(4) )        as SelectedSourceType,
      cast( case Selection.srctype
              when 'EDI'  then 'Fournisseur EDI'
              when 'WHSE' then 'Entrepôt'
              when 'STOR' then 'Centre voisin'
              when 'CASH' then 'Commande petite caisse'
              else             ''
            end as abap.char(40) )                     as SelectedSourceTypeText,
      cast( Selection.srcid as abap.char(10) )         as SelectedSourceId,

      -- avancement du traitement du poste
      @ObjectModel.text.element: [ 'SourceStatusText' ]
      case when Item.FollowOnDocument <> ''  then 'CONV'
           when Selection.srctype     <> ''  then 'SEL'
           else                                   'TODO'
      end                                              as SourceStatus,
      cast( case when Item.FollowOnDocument <> '' then 'Approvisionnement lancé'
                 when Selection.srctype     <> '' then 'Source choisie'
                 else                                  'À traiter'
            end as abap.char(40) )                     as SourceStatusText,

      case when Item.FollowOnDocument <> '' then 3
           when Selection.srctype     <> '' then 2
           else                                 1
      end                                              as SourceCriticality,

      _SourceOption
}
