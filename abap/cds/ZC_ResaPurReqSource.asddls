@EndUserText.label: 'Détermination de la source d''approvisionnement'
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'PurchaseRequisition', 'PurchaseRequisitionItem' ]

-- Projection exposée par le service ZUI_RESASRC. Une seule tuile, donc une seule projection :
-- la maquette en exposait quatre pour deux alternatives, l'arbitrage les a ramenées à une.
--
-- ⚠️ À vérifier (relevé R6) : si le compilateur refuse « provider contract transactional_query »,
-- retirer la clause — le service reste fonctionnel.

define root view entity ZC_ResaPurReqSource
  provider contract transactional_query
  as projection on ZR_ResaPurReqSource
{
  key PurchaseRequisition,
  key PurchaseRequisitionItem,

      Plant,
      PurchasingGroup,
      PurchasingOrganization,
      Material,
      PurchaseRequisitionItemText,

      Reservation,
      OriginType,
      OriginTypeText,

      PurReqDate,
      DeliveryDate,

      RequestedQuantity,
      BaseUnit,

      ItemAmount,
      Currency,

      SelectedSourceType,
      SelectedSourceId,
      SelectedSourceName,
      SelectedNetPrice,
      SelectedLeadTimeDays,

      SelectionStatus,
      SelectionStatusText,
      SelectionCriticality,
      SelectionMessage,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt
}
