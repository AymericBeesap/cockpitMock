@AbapCatalog.sqlViewName: 'ZIRESACHAIN'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chaîne réservation - DA - commande d''achat'
@Analytics.dataCategory: #CUBE

-- ⚠️ Vérifier dans ADT les noms réels des champs de I_PurchaseRequisitionItem :
--    ZZReservation, SalesOrder / SalesOrderItem, PurchaseOrder / PurchaseOrderItem.
define view ZI_ResaChainCube
  as select from I_PurchaseRequisitionItem as PurReqItem

    left outer join I_SalesOrderItem as SalesItem
      on  PurReqItem.SalesOrder     = SalesItem.SalesOrder
      and PurReqItem.SalesOrderItem = SalesItem.SalesOrderItem

    left outer join I_PurchaseOrderItem as PoItem
      on  PurReqItem.PurchaseOrder     = PoItem.PurchaseOrder
      and PurReqItem.PurchaseOrderItem = PoItem.PurchaseOrderItem

    -- aval alternatif : commande petite caisse rattachée au poste (socle source d'appro)
    left outer join ztresa_pcorder      as PettyCash
      on  PettyCash.banfn = PurReqItem.PurchaseRequisition
      and PettyCash.bnfpo = PurReqItem.PurchaseRequisitionItem
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

      -- libellé de l'origine (ajout par rapport au MO : évite l'affichage des codes)
      cast( case when PurReqItem.ZZReservation <> '' then 'Réservation magasin'
                 when PurReqItem.SalesOrder    <> '' then 'Commande client'
                 else                                     'Autre'
            end as abap.char(40) )               as OriginTypeText,

      -- document aval : commande d'achat ou commande petite caisse
      cast( case when PurReqItem.PurchaseOrder <> '' then PurReqItem.PurchaseOrder
                 when PettyCash.pcnum          <> '' then PettyCash.pcnum
                 else                                     ''
            end as abap.char(10) )               as FollowOnDocument,

      cast( case when PurReqItem.PurchaseOrder <> '' then 'ZDI5'
                 when PettyCash.pcnum          <> '' then 'ZPC'
                 else                                     ''
            end as abap.char(4) )                as FollowOnDocumentType,

      -- étape atteinte dans la chaîne
      case when PurReqItem.PurchaseOrder <> '' then 'PO'
           when PettyCash.pcnum          <> '' then 'PC'
           else                                     'PR'
      end                                        as ChainStage,

      -- libellé de l'étape (ajout par rapport au MO)
      cast( case when PurReqItem.PurchaseOrder <> '' then 'Commande d''achat créée'
                 when PettyCash.pcnum          <> '' then 'Commande petite caisse'
                 else                                     'Demande d''achat en attente'
            end as abap.char(40) )               as ChainStageText,

      -- mesures
      1                                          as PurReqItemCount,

      case when PurReqItem.PurchaseOrder <> ''
           then 1 else 0 end                     as ConvertedItemCount,

      -- un poste soldé en petite caisse n'est plus en attente d'approvisionnement
      case when PurReqItem.PurchaseOrder =  ''
            and PettyCash.pcnum          =  ''
           then 1 else 0 end                     as OpenItemCount,

      case when PurReqItem.PurchaseOrder <> ''
            or PettyCash.pcnum           <> ''
           then 3 else 2 end                     as ChainCriticality,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      PurReqItem.RequestedQuantity,
      PurReqItem.BaseUnit,

      @Semantics.amount.currencyCode: 'Currency'
      PurReqItem.PurchaseRequisitionPrice        as ItemAmount,
      PurReqItem.Currency
}
