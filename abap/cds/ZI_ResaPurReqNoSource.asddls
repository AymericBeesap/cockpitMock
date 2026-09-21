@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Postes de DA sans source d''approvisionnement'
@Metadata.ignorePropagatedAnnotations: true

-- Liste de travail : postes de demande d'achat ouverts pour lesquels aucune source
-- d'approvisionnement n'est renseignée. C'est le seul filtre métier de l'application ;
-- tout le reste du cockpit passe par les tuiles standard de DA et de commande d'achat.
--
-- ⚠️ À vérifier (relevé R1) — noms réels des éléments de I_PurchaseRequisitionItem dans le système :
--    ZZReservation, FixedSupplier, PurchasingInfoRecord, SupplyingPlant, PurchaseContract,
--    PurchaseOrder, PurchaseRequisitionReleaseDate, DeliveryDate, PurchaseRequisitionPrice,
--    ainsi que les indicateurs de suppression et de clôture. Corriger ci-dessous si nécessaire.

define view entity ZI_ResaPurReqNoSource
  as select from I_PurchaseRequisitionItem as PurReqItem
{
  key PurReqItem.PurchaseRequisition,
  key PurReqItem.PurchaseRequisitionItem,

      PurReqItem.Plant,
      PurReqItem.PurchasingGroup,
      PurReqItem.PurchasingOrganization,
      PurReqItem.Material,
      PurReqItem.PurchaseRequisitionItemText,

      -- origine du besoin : réservation magasin transmise par IDoc, ou autre
      PurReqItem.ZZReservation                     as Reservation,

      cast( case when PurReqItem.ZZReservation <> '' then 'RESA'
                 else                                     'AUTR'
            end as abap.char(4) )                  as OriginType,

      cast( case when PurReqItem.ZZReservation <> '' then 'Réservation magasin'
                 else                                     'Autre besoin'
            end as abap.char(40) )                 as OriginTypeText,

      PurReqItem.PurchaseRequisitionReleaseDate    as PurReqDate,
      PurReqItem.DeliveryDate,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      PurReqItem.RequestedQuantity,
      PurReqItem.BaseUnit,

      @Semantics.amount.currencyCode: 'Currency'
      PurReqItem.PurchaseRequisitionPrice          as ItemAmount,
      PurReqItem.Currency
}
where
      -- aucune source d'approvisionnement renseignée (R1)
      PurReqItem.FixedSupplier            =  ''
  and PurReqItem.PurchasingInfoRecord     =  ''
  and PurReqItem.SupplyingPlant           =  ''
  and PurReqItem.PurchaseContract         =  ''
      -- poste encore à approvisionner
  and PurReqItem.PurchaseOrder            =  ''
  and PurReqItem.PurchaseRequisitionItemIsDeleted = ''
  and PurReqItem.PurReqnItemIsClosed              = ''
