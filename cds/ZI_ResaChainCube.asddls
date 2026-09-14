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

      -- étape atteinte dans la chaîne
      case when PurReqItem.PurchaseOrder <> '' then 'PO'
           else                                     'PR'
      end                                        as ChainStage,

      -- libellé de l'étape (ajout par rapport au MO)
      cast( case when PurReqItem.PurchaseOrder <> '' then 'Commande d''achat créée'
                 else                                     'Demande d''achat en attente'
            end as abap.char(40) )               as ChainStageText,

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
